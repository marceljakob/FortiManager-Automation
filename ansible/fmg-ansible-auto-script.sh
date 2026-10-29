#!/usr/bin/env bash
# =============================================================================
#  FortiManager + Ansible - Auto Setup Script (Ubuntu)
#
#  - Installs Ansible and the fortinet.fortimanager collection
#  - Creates the project structure (default: ~/dev-fmg-ansible)
#  - Creates ansible.cfg, hosts.ini, vars.yml and an encrypted vault.yml
#  - Supports Username/Password or API token authentication
#  - Creates the test playbook 00-r-get_status.yml
#  - Optionally runs the test playbook
#
#  Usage:  chmod +x fmg-ansible-setup.sh && ./fmg-ansible-setup.sh
#  Run as a normal user (sudo is used only for the package installation).
# =============================================================================
set -euo pipefail

# ---------- Output helpers (all to stderr, so they don't mix with captured input)
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*" >&2; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*" >&2; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
die()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
step()  { echo -e "\n${BOLD}==> $*${NC}" >&2; }

# ---------- Input helpers
# ask "Prompt" "default"  -> prints the value (default if empty input)
ask() {
  local prompt="$1" default="${2:-}" value=""
  while true; do
    if [[ -n "$default" ]]; then
      read -rp "$prompt [$default]: " value
      value="${value:-$default}"
    else
      read -rp "$prompt: " value
    fi
    [[ -n "$value" ]] && { printf '%s' "$value"; return; }
    warn "Value must not be empty."
  done
}

# ask_secret "Prompt"  -> hidden input with confirmation
ask_secret() {
  local prompt="$1" s1 s2
  while true; do
    read -rsp "$prompt: " s1; echo >&2
    [[ -z "$s1" ]] && { warn "Value must not be empty."; continue; }
    read -rsp "Confirm $prompt: " s2; echo >&2
    [[ "$s1" == "$s2" ]] && { printf '%s' "$s1"; return; }
    warn "Values do not match. Please try again."
  done
}

# ask_yn "Question" "y|n"  -> returns 0 for yes, 1 for no
ask_yn() {
  local prompt="$1" default="${2:-y}" answer hint
  [[ "$default" == "y" ]] && hint="Y/n" || hint="y/N"
  read -rp "$prompt [$hint]: " answer
  answer="${answer:-$default}"
  [[ "${answer,,}" == y* ]]
}

# YAML single-quote escaping ('  ->  '')
yaml_quote() { local s="${1//\'/\'\'}"; printf "'%s'" "$s"; }

# ---------- Safety: never leave an unencrypted vault.yml behind
VAULT_YML=""
cleanup() {
  if [[ -n "$VAULT_YML" && -f "$VAULT_YML" ]] && ! head -1 "$VAULT_YML" | grep -q '^\$ANSIBLE_VAULT'; then
    rm -f "$VAULT_YML"
    warn "Removed unencrypted vault.yml (setup did not finish)."
  fi
  unset FMG_PASS FMG_TOKEN VAULT_PASS 2>/dev/null || true
}
trap cleanup EXIT

# =============================================================================
#  0. Pre-checks
# =============================================================================
echo -e "${BOLD}FortiManager + Ansible - Auto Setup${NC}"

[[ $EUID -eq 0 ]] && die "Please run this script as a normal user, not as root."
command -v apt-get >/dev/null || die "apt-get not found. This script supports Ubuntu only."
if ! grep -qi '^ID=ubuntu' /etc/os-release 2>/dev/null; then
  warn "This system does not look like Ubuntu."
  ask_yn "Continue anyway?" "n" || exit 1
fi

# =============================================================================
#  1. Installation
# =============================================================================
step "1/6 Installing Ansible and the FortiManager collection"
sudo apt-get update -y
sudo apt-get install -y ansible
ansible-galaxy collection install fortinet.fortimanager --upgrade
ok "Ansible $(ansible --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1) and fortinet.fortimanager installed."

# =============================================================================
#  2. User input
# =============================================================================
step "2/6 Project and FortiManager settings"

PROJECT_NAME=$(ask "Project folder name (created in $HOME)" "dev-fmg-ansible")
PROJECT_DIR="$HOME/$PROJECT_NAME"
if [[ -d "$PROJECT_DIR" && -n "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]]; then
  warn "Folder $PROJECT_DIR already exists and is not empty."
  ask_yn "Overwrite the setup files in this folder?" "n" || die "Aborted by user."
fi

while true; do
  FMG_NAME=$(ask "FortiManager inventory name" "FORTIMANAGER-1")
  [[ "$FMG_NAME" =~ ^[A-Za-z0-9_.-]+$ ]] && break
  warn "Only letters, numbers, '-', '_' and '.' are allowed (no spaces)."
done

while true; do
  FMG_IP=$(ask "FortiManager IP address or hostname")
  [[ "$FMG_IP" =~ ^[A-Za-z0-9.:-]+$ ]] && break
  warn "Invalid IP address or hostname."
done

while true; do
  FMG_PORT=$(ask "FortiManager HTTPS port" "443")
  [[ "$FMG_PORT" =~ ^[0-9]+$ ]] && (( FMG_PORT >= 1 && FMG_PORT <= 65535 )) && break
  warn "Port must be a number between 1 and 65535."
done

# Authentication method
echo "Authentication method:" >&2
echo "  [1] Username / Password" >&2
echo "  [2] API Token" >&2
while true; do
  AUTH_CHOICE=$(ask "Select authentication method" "1")
  case "$AUTH_CHOICE" in
    1) AUTH_METHOD="password"; break ;;
    2) AUTH_METHOD="token";    break ;;
    *) warn "Please enter 1 or 2." ;;
  esac
done

FMG_USER=""; FMG_PASS=""; FMG_TOKEN=""
if [[ "$AUTH_METHOD" == "password" ]]; then
  FMG_USER=$(ask "FortiManager API username" "ansible-admin")
  FMG_PASS=$(ask_secret "FortiManager API password")
else
  FMG_TOKEN=$(ask_secret "FortiManager API token")
fi

# Vault password file
VAULT_PASS_FILE="$HOME/.ansible/vault_pass.txt"
CREATE_VAULT_PASS=true
if [[ -f "$VAULT_PASS_FILE" ]]; then
  warn "Vault password file already exists: $VAULT_PASS_FILE"
  if ask_yn "Use the existing vault password?" "y"; then
    CREATE_VAULT_PASS=false
  else
    warn "A new vault password makes other vaults encrypted with the old one unreadable."
    ask_yn "Create a new vault password anyway?" "n" || die "Aborted by user."
  fi
fi
if $CREATE_VAULT_PASS; then
  VAULT_PASS=$(ask_secret "New Ansible Vault password")
fi

# Summary
echo >&2
echo -e "${BOLD}Summary${NC}" >&2
echo "  Project folder : $PROJECT_DIR" >&2
echo "  FMG name       : $FMG_NAME" >&2
echo "  FMG address    : $FMG_IP:$FMG_PORT" >&2
if [[ "$AUTH_METHOD" == "password" ]]; then
  echo "  Authentication : Username / Password (user: $FMG_USER)" >&2
else
  echo "  Authentication : API Token" >&2
fi
echo "  Vault password : $($CREATE_VAULT_PASS && echo "new" || echo "existing") ($VAULT_PASS_FILE)" >&2
echo >&2
ask_yn "Create the project with these settings?" "y" || die "Aborted by user."

# =============================================================================
#  3. Folder structure and config files
# =============================================================================
step "3/6 Creating folder structure and files"

mkdir -p "$PROJECT_DIR"/{inventory/group_vars/fortimanagers,playbooks}
cd "$PROJECT_DIR"

cat > ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts.ini
vault_password_file = ~/.ansible/vault_pass.txt
callback_result_format = yaml
gathering = explicit

[persistent_connection]
command_timeout = 60
EOF

cat > inventory/hosts.ini << EOF
[fortimanagers]
${FMG_NAME} ansible_host=${FMG_IP}
EOF

cat > inventory/group_vars/fortimanagers/vars.yml << EOF
ansible_connection: httpapi
ansible_network_os: fortinet.fortimanager.fortimanager
ansible_httpapi_use_ssl: true
ansible_httpapi_validate_certs: false
ansible_httpapi_port: ${FMG_PORT}
EOF

if [[ "$AUTH_METHOD" == "password" ]]; then
  cat >> inventory/group_vars/fortimanagers/vars.yml << 'EOF'

# Authentication: Username / Password
ansible_user: "{{ vault_fmg_user }}"
ansible_password: "{{ vault_fmg_password }}"
EOF
else
  cat >> inventory/group_vars/fortimanagers/vars.yml << 'EOF'

# Authentication: API Token
ansible_httpapi_session_key:
  authorization: "bearer {{ vault_fmg_token }}"
EOF
fi

cat > .gitignore << 'EOF'
vault_pass.txt
.vault_pass*
*.retry
EOF

ok "ansible.cfg, hosts.ini, vars.yml and .gitignore created."

# =============================================================================
#  4. Vault password file and encrypted vault.yml
# =============================================================================
step "4/6 Creating Ansible Vault"

if $CREATE_VAULT_PASS; then
  mkdir -p "$HOME/.ansible"
  ( umask 077; printf '%s\n' "$VAULT_PASS" > "$VAULT_PASS_FILE" )
  chmod 600 "$VAULT_PASS_FILE"
  unset VAULT_PASS
  ok "Vault password file created: $VAULT_PASS_FILE"
fi

VAULT_YML="$PROJECT_DIR/inventory/group_vars/fortimanagers/vault.yml"
(
  umask 077
  if [[ "$AUTH_METHOD" == "password" ]]; then
    printf 'vault_fmg_user: %s\n'     "$(yaml_quote "$FMG_USER")"  > "$VAULT_YML"
    printf 'vault_fmg_password: %s\n' "$(yaml_quote "$FMG_PASS")" >> "$VAULT_YML"
  else
    printf 'vault_fmg_token: %s\n'    "$(yaml_quote "$FMG_TOKEN")" > "$VAULT_YML"
  fi
)
unset FMG_PASS FMG_TOKEN
ansible-vault encrypt "$VAULT_YML" --encrypt-vault-id default >/dev/null

# =============================================================================
#  5. Verify encryption
# =============================================================================
step "5/6 Verifying encryption"

head -1 "$VAULT_YML" | grep -q '^\$ANSIBLE_VAULT' \
  || die "vault.yml is NOT encrypted."
ansible-vault view "$VAULT_YML" >/dev/null \
  || die "vault.yml could not be decrypted with the vault password."
ok "vault.yml is encrypted ($(head -1 "$VAULT_YML"))."

# =============================================================================
#  6. Test playbook
# =============================================================================
step "6/6 Creating test playbook"

cat > playbooks/00-r-get_status.yml << 'EOF'
- name: FortiManager Status
  hosts: fortimanagers
  gather_facts: false

  tasks:
    - name: Get system information
      fortinet.fortimanager.fmgr_fact:
        facts:
          selector: sys_status
      register: status

    - name: Show response
      ansible.builtin.debug:
        msg: >-
          Hostname: {{ status.meta.response_data.Hostname | default('?') }},
          Version: {{ status.meta.response_data.Version | default('?') }},
          Serial number: {{ status.meta.response_data['Serial Number'] | default('?') }}
EOF

ansible-playbook playbooks/00-r-get_status.yml --syntax-check >/dev/null \
  && ok "playbooks/00-r-get_status.yml created (syntax OK)."

# =============================================================================
#  Done
# =============================================================================
echo -e "\n${GREEN}${BOLD}Project successfully created: $PROJECT_DIR${NC}\n" >&2

RUN_CMD="ansible-playbook playbooks/00-r-get_status.yml"

if ask_yn "Run the test playbook now?" "y"; then
  info "Running: cd $PROJECT_DIR && $RUN_CMD"
  echo >&2
  if ! ansible-playbook playbooks/00-r-get_status.yml; then
    echo >&2
    warn "Playbook failed. Common causes:"
    if [[ "$AUTH_METHOD" == "token" ]]; then
      warn "  - Invalid API token or REST API admin without 'JSON API Access: Read-Write'"
    else
      warn "  - Wrong credentials or API user without 'JSON API Access: Read-Write'"
    fi
    warn "  - Ansible host IP not in the Trusted Hosts of the API user"
    warn "  - FortiManager not reachable on $FMG_IP:$FMG_PORT"
  fi
else
  echo -e "Run the test playbook manually:\n" >&2
  echo "  cd $PROJECT_DIR" >&2
  echo "  $RUN_CMD" >&2
fi
echo >&2
