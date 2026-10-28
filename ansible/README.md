# Official Documentation
Galaxy Ansible: https://galaxy.ansible.com/ui/repo/published/fortinet/fortimanager/

# Prerequisits
- Linux VM
- FortiManager API User with JSON API Access: Read-Write and Trusted Hosts

# Before you start
There are two ways to continuing with the setup:
1. Manual follow through
2. Full script with loop

If you don`t want to manual configure the setup, it is still recommended to read/understand it, before using the "Auto Script".

# Preparation
## Install Ansible
```
apt-get update
apt-get -y install ansible
```
## Update Ansible Collection
```
ansible-galaxy collection install fortinet.fortimanager
ansible-galaxy collection install fortinet.fortimanager --upgrade
```
Optional - select custom version:
```
ansible-galaxy collection install fortinet.fortimanager:==2.0.0
```

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
    └── 0X_XXXX.yml
```
The whole work will be done in the folder /home/your-user/dev-fmg-ansible.
## Explanation
- **ansible.cfg**:
- **hosts.ini**:
- **vars.yml**:
- **vault.yml**: 

## 1. Folder Structure Creation
```
mkdir -p ~/dev-fmg-ansible/{inventory/group_vars/fortimanagers,playbooks}
cd ~/dev-fmg-ansible/
```
## 2. Add ansible.cfg
```
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
```
nano inventory/hosts.ini
```
**File content:**
```
[fortimanagers]
MY-FORTIMANAGER-1 ansible_host=XXX.XXX.XXX.XXX        # Change Name & IP
```
## 4. Add vars.yml
```
nano inventory/group_vars/fortimanagers/vars.yml
```
**File content:**
```
ansible_connection: httpapi
ansible_network_os: fortinet.fortimanager.fortimanager
ansible_httpapi_use_ssl: true
ansible_httpapi_validate_certs: false
ansible_httpapi_port: 443                    # Change Custom HTTPS Port if necessary

ansible_user: "{{ vault_fmg_user }}"
ansible_password: "{{ vault_fmg_password }}"
```
## 5. Add vault.yml
This setup is considered only for testing and development, nevertheless we should handle secrts and passwords securly - gerade im bezug wenn wir mit git arbeiten.
Deswegen legen wir das Passwort für den Ansible Vault innerhalb unseren Linux Benutzer Profils ab. Das Passwort liegt hierbei im klartext.
Der Ansible Projekt Ordner greift auf dieses passwort zu und hat es somit nicht direkt im ordner.
```
mkdir -p ~/.ansible
read -rs -p "Vault password: " PW; echo
printf '%s\n' "$PW" > ~/.ansible/vault_pass.txt; unset PW
chmod 600 ~/.ansible/vault_pass.txt
```
Vault Creation
```
EDITOR=nano ansible-vault create inventory/group_vars/fortimanagers/vault.yml
```
**File content:**
```
vault_fmg_user: "ansible-admin"
vault_fmg_password: "YOUR FMG ANSIBLE ADMIN PW"

```
## 6. Create Playbooks
With this playbook we can see if the access is working.
For further examples, see the folder examples within this project.

# Auto Script
