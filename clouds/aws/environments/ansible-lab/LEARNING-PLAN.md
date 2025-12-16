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

### In Progress
- [ ] **Lesson 4: Configuring FreeRADIUS** - paused here
  - Create role structure (`playbooks/roles/freeradius/`)
  - Create tasks/main.yml
  - Create templates (users.j2, clients.conf.j2)
  - Create handlers (restart service)

### Remaining
- [ ] Lesson 5: Test with radtest
- [ ] Lesson 6: GitHub Actions workflow for Ansible
- [ ] Lesson 7: End-to-end test (destroy/recreate/deploy)

---

## Quick Reference

### EC2 Instance
```
IP: 3.14.253.164
SSH: ssh -i ~/.ssh/ansible-lab ubuntu@3.14.253.164
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
