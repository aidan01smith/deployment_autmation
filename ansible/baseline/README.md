# Ansible — guest & host configuration

Terraform builds the VMs; **Ansible configures everything inside (and the
Proxmox host itself).** Ansible is agentless — it connects over SSH and runs
modules remotely. Modules are *idempotent*: you declare desired state and
re-running is safe.

## Layout

```
ansible.cfg                 # defaults (points at the dynamic inventory)
baseline/
  example_hosts.ini         # static inventory example (learn the model)
  hosts.ini                 # your static inventory (optional)
  homelab.proxmox.yml       # DYNAMIC inventory — pulls hosts from Proxmox API
  main.yml                  # top-level playbook: ubuntu -> tailscale -> services
  ubuntu/                   # base OS: packages, user, hardening
  tailscale/                # join the mesh VPN
  services/                 # one file per self-hosted app, all via docker compose
  proxmox/                  # tasks that run against the HYPERVISOR (build template, API users)
```

## Core concepts (the 60-second version)

- **Inventory** = the list of machines. Static (`.ini`) or dynamic
  (`.proxmox.yml`, queried live).
- **Play** = "run these roles/tasks on this group of hosts."
- **Task** = one call to one **module** (`apt`, `service`, `docker_compose_v2`…).
- **Role** = a reusable bundle of tasks (the dirs under `baseline/`).
- **Handler** = a task that runs only when notified (e.g. restart sshd once).
- **Variables / Vault** = parameterize everything; encrypt secrets with
  `ansible-vault`.

## First-time setup

```bash
pip install ansible proxmoxer requests
ansible-galaxy collection install community.proxmox community.docker community.general ansible.posix

# Tell the dynamic inventory how to auth (token secret via env var):
export PROXMOX_TOKEN="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Verify discovery:
ansible-inventory -i baseline/homelab.proxmox.yml --graph
```

## Running

```bash
# Dry run first — shows diffs, changes nothing:
ansible-playbook baseline/main.yml --check --diff --ask-vault-pass

# For real:
ansible-playbook baseline/main.yml --ask-vault-pass

# Just one host or group:
ansible-playbook baseline/main.yml --limit tag_media
```

## How it connects to Terraform

Terraform tags each VM (`services`, `docker`, `media`…). The dynamic inventory
turns those tags into Ansible groups (`tag_services`, etc.) via `keyed_groups`.
So adding a VM in Terraform automatically makes it targetable in Ansible — no
hand-edited host list.

