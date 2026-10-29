# Official Documentation
Galaxy Ansible: https://galaxy.ansible.com/ui/repo/published/fortinet/fortimanager/
<br/><br/>

# Prerequisites
- Linux VM (Ubuntu) with sudo rights 
- Network access to the FortiManager (HTTPS)
- FortiManager API user with *JSON API Access: Read-Write* and Trusted Hosts
</br></br>

# Before you start
There are two ways to set up the project:
1. Manual setup (step by step)
2. Auto script

Even if you use the auto script, read the manual steps first to understand the setup.
<br/>
## Authentication Methods
Two methods are supported. Choose one per FortiManager.

| Method | Ansible variables | Recommended for |
|---|---|---|
| Username / Password | `ansible_user`, `ansible_password` | Quick start, lab |
| API Token | `ansible_httpapi_session_key` | Automation, CI/CD (no password in use) |

The authentication is configured only in the inventory (vars.yml / vault.yml). Playbooks are the same for both methods.

# Preparation
## Install Ansible
```bash
sudo apt-get update
sudo apt-get -y install ansible
```
## Update Ansible Collection
```bash
ansible-galaxy collection install fortinet.fortimanager --upgrade
```
Optional - select custom version:
```bash
ansible-galaxy collection install fortinet.fortimanager:==<version>
```
> **Note:** Since FortiManager 7.6.5, the API endpoint for scripts has changed.
> Some modules (e.g. `fmgr_dvmdb_script`) may not work. Use `fmgr_generic` instead.
<br/><br/>

# Project Setup
```text
dev-fmg-ansible
├── ansible.cfg                  # manually created
├── inventory/
│   ├── hosts.ini                # manually created
│   └── group_vars/
│       └── fortimanagers/
│           ├── vars.yml         # manually created
│           └── vault.yml        # automatically created (ansible-vault)
└── playbooks/
    └── 00-r-get_status.yml      # manually created
```
All commands are run from `~/dev-fmg-ansible`.
## Explanation
- **ansible.cfg**: Project settings (inventory path, vault password file, output format).
- **hosts.ini**: List of FortiManagers (name and IP).
- **vars.yml**: Connection settings for all FortiManagers.
- **vault.yml**: Encrypted credentials.
- **playbooks/**: The automation tasks.
<br/>

## 1. Folder Structure Creation
```bash
mkdir -p ~/dev-fmg-ansible/{inventory/group_vars/fortimanagers,playbooks}
cd ~/dev-fmg-ansible/
```
<br/>

## 2. Add ansible.cfg
```bash
nano ansible.cfg
```
**File content:**
```ini
[defaults]
inventory = inventory/hosts.ini
vault_password_file = ~/.ansible/vault_pass.txt
callback_result_format = yaml
gathering = explicit

[persistent_connection]
command_timeout = 60
```
<br/>

## 3. Add hosts.ini
```bash
nano inventory/hosts.ini
```
**File content:**
```ini
[fortimanagers]
MY-FORTIMANAGER-1 ansible_host=XXX.XXX.XXX.XXX        # change name and IP
```
<br/>

## 4. Add vars.yml
```bash
nano inventory/group_vars/fortimanagers/vars.yml
```
**File content:**
```yaml
ansible_connection: httpapi
ansible_network_os: fortinet.fortimanager.fortimanager
ansible_httpapi_use_ssl: true
ansible_httpapi_validate_certs: false
ansible_httpapi_port: 443                    # change if FMG uses a custom HTTPS port

# --- Option A: Username / Password ---
ansible_user: "{{ vault_fmg_user }}"
ansible_password: "{{ vault_fmg_password }}"

# --- Option B: API Token ---
# ansible_httpapi_session_key:
#   authorization: "bearer {{ vault_fmg_token }}"
```
> **Note:** Use only one option. Do not define both at the same time.
<br/>

## 5. Add vault.yml
This setup is for testing and development only. Still, secrets must be handled securely – especially when using Git.
The vault password is stored in the user's home directory (`~/.ansible/vault_pass.txt`), outside the project folder. It is stored in plain text, but only readable by the user (`chmod 600`) and never committed to Git.

**Create the vault password file:**
```bash
mkdir -p ~/.ansible
read -rs -p "Vault password: " PW; echo
printf '%s\n' "$PW" > ~/.ansible/vault_pass.txt; unset PW
chmod 600 ~/.ansible/vault_pass.txt
```
**Create the vault:**
```bash
EDITOR=nano ansible-vault create inventory/group_vars/fortimanagers/vault.yml
```
**File content - Option A (Username/Password):**
```yaml
vault_fmg_user: "ansible-admin"
vault_fmg_password: "YOUR FMG ANSIBLE ADMIN PW"
```
**File content - Option B (API Token):**
```yaml
vault_fmg_token: "YOUR-API-TOKEN"
```
**Verify encryption:**
```bash
head -1 inventory/group_vars/fortimanagers/vault.yml
# Expected: $ANSIBLE_VAULT;1.1;AES256
```
<br/>

## 6. Create Playbooks
With this playbook we can see if the access is working.
For further examples, see the folder examples within this project.
```bash
nano playbooks/00-r-get_status.yml
```
**File content:**
```yaml
- name: FortiManager Status
  hosts: fortimanagers
  gather_facts: false

  tasks:
    - name: get system information
      fortinet.fortimanager.fmgr_fact:
        facts:
          selector: sys_status
      register: status

    - name: show response
      ansible.builtin.debug:
        msg: >-
          Hostname: {{ status.meta.response_data.Hostname | default('?') }},
          Version: {{ status.meta.response_data.Version | default('?') }},
          Serial number: {{ status.meta.response_data['Serial Number'] | default('?') }}
```
More playbooks are available in the [`examples`](./examples) folder.

**Naming convention:** `<level>-<mode>-<name>.yml`

| Part | Value | Meaning |
|---|---|---|
| Level | `00` | Basic |
| | `01` | Advanced |
| | `02` | Complex |
| | `03` | Very complex |
| Mode | `r` | Read-only – no changes on the FortiManager |
| | `w` | Write – changes the FortiManager configuration |

Example: `00-r-get_status.yml` = basic, read-only playbook.

> **Note:** Test `w` playbooks in a lab first.
<br/>

## 7. Execute Playbook
```bash
ansible-playbook playbooks/00-r-get_status.yml
```
<br/><br/>

# Troubleshooting

| Error | Cause | Solution |
|---|---|---|
| `Can't login. Your login method is username_password` | Wrong credentials, missing API permission or IP not allowed | Check *JSON API Access: Read-Write* and Trusted Hosts of the API user |
| `-3 Object does not exist` | Wrong ADOM name (case-sensitive) or outdated API path | Check ADOM name; for scripts on FMG ≥ 7.6.5 use `fmgr_generic` |
| `Unsupported parameters ... adom` | Parameter at the wrong level | Move it under `facts: params:` (for `fmgr_fact`) |
| `No inventory was parsed` | Playbook not started from the project folder | Run all commands from `~/dev-fmg-ansible` |
| `No fact modules available` | Fact gathering is enabled | Set `gather_facts: false` in the playbook |
| `File contains no section headers` | `[defaults]` missing in `ansible.cfg` | Add `[defaults]` as the first line |
| `expected dicts but got ... Str` | Wrong format in `vault.yml` | Use `key: "value"` (space after the colon) |
| `Mapping values are not allowed` | YAML indentation error | Use spaces only (no tabs), 2 per level |
| Timeout / connection refused | HTTPS not reachable | Check network, `allowaccess https` and `ansible_httpapi_port` |

**Useful commands:**
```bash
ansible --version                                      # shows which ansible.cfg is used
ansible-inventory --host <name>                        # shows resolved variables
ansible-playbook <playbook>.yml --syntax-check         # checks YAML syntax
ansible-playbook <playbook>.yml -vvv                   # verbose output
```

<br/><br/>
# Auto Script
*Coming soon.*
