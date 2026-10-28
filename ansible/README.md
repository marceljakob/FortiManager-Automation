# Official Documentation
Galaxy Ansible: https://galaxy.ansible.com/ui/repo/published/fortinet/fortimanager/

# Prerequisits
- Linux VM
- FortiManager API User with Permission (JSON)

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
```text
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
1. Folder Structure Creation
2. Add ansible.cfg
3. Add hosts.ini
4. Add vars.yml
5. Add vault.yml
6. Create Playbooks
