# Ansible + FreeRADIUS Learning Lab

## Goal
Green belt in Ansible - solid fundamentals for job interview prep.

## Progress

### Completed
- [x] SSH key generated (`~/.ssh/ansible-lab`)
- [x] Terraform infrastructure deployed (EC2 + VPC)
- [x] Ansible installed locally
- [x] Inventory file created (`ansible/inventory/hosts.yml`)
- [x] ansible.cfg configured (defaults, no warnings)
- [x] First playbook created (`ansible/playbooks/freeradius.yml`)
- [x] FreeRADIUS packages installed on server

### Completed
- [x] **Lesson 4: Configuring FreeRADIUS**
  - Created role structure (`playbooks/roles/freeradius/`)
  - Created tasks/main.yml (install + configure)
  - Created templates (users.j2, clients.conf.j2) with Jinja2 loops
  - Created handlers (restart service on config change)
  - Learned: FreeRADIUS 3.x reads from `mods-config/files/authorize`
- [x] **Lesson 5: Test with radtest**
  - Verified testuser and alice authenticate successfully
  - Verified wrong passwords get rejected
- [x] **Lesson 6: GitHub Actions workflow for Ansible**
  - Created `.github/workflows/ansible-lint.yml`
  - Uses `uv` for Python package management
  - Runs ansible-lint on push, PR, and manual trigger
  - Fixed YAML formatting issues to pass linting
- [x] **Lesson 7: End-to-end test (destroy/recreate/deploy)**
  - Destroyed all 8 resources with `tofu destroy`
  - Recreated infrastructure with `tofu apply`
  - Ran Ansible playbook on fresh server
  - Verified FreeRADIUS authentication works

### All lessons complete!

---

## Quick Reference

### EC2 Instance
```
IP: 18.119.17.172
SSH: ssh -i ~/.ssh/ansible-lab ubuntu@18.119.17.172
```

### Commands Learned
```bash
# Test connectivity
ansible radius-server -m ping

# Run playbook
ansible-playbook playbooks/freeradius.yml

# Ad-hoc command example
ansible radius-server -m shell -a "systemctl status freeradius"
```

### Directory Structure (target)
```
ansible/
├── ansible.cfg
├── inventory/
│   └── hosts.yml
└── playbooks/
    ├── freeradius.yml          # Main playbook (calls role)
    └── roles/
        └── freeradius/
            ├── tasks/main.yml      # Installation + config tasks
            ├── templates/
            │   ├── users.j2        # Test user config
            │   └── clients.conf.j2 # RADIUS client config
            └── handlers/main.yml   # Restart service handler
```

---

## FreeRADIUS Concepts

**RADIUS = Remote Authentication Dial-In User Service**

Three functions (AAA):
- **Authentication** - "Who are you?" (username/password)
- **Authorization** - "What can you access?"
- **Accounting** - "What did you do?" (logging)

**Key files on the server:**
- `/etc/freeradius/3.0/users` - User accounts
- `/etc/freeradius/3.0/clients.conf` - Allowed RADIUS clients

**Testing tool:**
```bash
radtest <username> <password> <server> <port> <shared-secret>
radtest testuser testpass 127.0.0.1 1812 testing123
```

---

## Cost Reminder

EC2 t3.micro: ~$8/month

To save money when not using:
```bash
cd /Users/silverbeer/gitrepos/missingtable-platform-bootstrap/clouds/aws/environments/ansible-lab
tofu destroy
```

To bring it back:
```bash
tofu apply
# Note: IP will change - update inventory/hosts.yml
```
