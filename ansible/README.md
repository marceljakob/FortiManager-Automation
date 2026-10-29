# Official Documentation
Galaxy Ansible: https://galaxy.ansible.com/ui/repo/published/fortinet/fortimanager/

# Prerequisites
- Linux VM with sudo rights
- Network access to the FortiManager (HTTPS)
- FortiManager API user with *JSON API Access: Read-Write* and Trusted Hosts

# Before you start
There are two ways to set up the project:
1. Manual setup (step by step)
2. Auto script

Even if you use the auto script, read the manual steps first to understand the setup.

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

# Project Setup
```
dev-fmg-ansible
├── ansible.cfg                  # manually created
├── inventory/
│   ├── hosts.ini                # manually created
│   └── group_vars/
│       └── fortimanagers/
│           ├── vars.yml         # manually created
│           └── vault.yml        # automatically created (ansible-vault)
└── playbooks/
    └── 00-r-get_status.yml
```
All commands are run from `~/dev-fmg-ansible`.
## Explanation
- **ansible.cfg**: Project settings (inventory path, vault password file, output format).
- **hosts.ini**: List of FortiManagers (name and IP).
- **vars.yml**: Connection settings for all FortiManagers.
- **vault.yml**: Encrypted credentials.
- **playbooks/**: The automation tasks.

## 1. Folder Structure Creation
```bash
mkdir -p ~/dev-fmg-ansible/{inventory/group_vars/fortimanagers,playbooks}
cd ~/dev-fmg-ansible/
```
## 2. Add ansible.cfg
```bash
nano ansible.cfg
```
**File content:**
```
[defaults]
inventory = inventory/hosts.ini
vault_password_file = ~/.ansible/vault_pass.txt
callback_result_format = yaml
gathering = explicit

[persistent_connection]
command_timeout = 60
```
## 3. Add hosts.ini
```bash
nano inventory/hosts.ini
```
**File content:**
```
[fortimanagers]
MY-FORTIMANAGER-1 ansible_host=XXX.XXX.XXX.XXX        # change name and IP
```
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
ansible_httpapi_port: 443                    # Change Custom HTTPS Port if necessary

ansible_user: "{{ vault_fmg_user }}"
ansible_password: "{{ vault_fmg_password }}"
```
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
**File content:**
```yaml
vault_fmg_user: "ansible-admin"
vault_fmg_password: "YOUR FMG ANSIBLE ADMIN PW"
```
**Verify encryption:**
```bash
head -1 inventory/group_vars/fortimanagers/vault.yml
# Expected: $ANSIBLE_VAULT;1.1;AES256
```
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
          Seriennummer: {{ status.meta.response_data['Serial Number'] | default('?') }}
```
## Execute Playbook
```bash
ansible-playbook playbooks/00-r-get_status.yml
```
# Auto Script
