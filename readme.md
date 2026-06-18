# Proxmox Homelab Automation

A learning-oriented Infrastructure-as-Code setup that provisions Proxmox VMs
with **Terraform** and configures them with **Ansible**, optionally driven
remotely through **Semaphore** over the **Proxmox API**.

The whole point is to read like documentation: every file is commented to
explain not just *what* it does but *why* it's written that way, so you pick up
the language and conventions of both tools.

## The big picture

```
                 ┌─────────────┐
   you / CI ───▶ │  Semaphore  │  (remote execution, schedules, secrets)
                 └──────┬──────┘
                        │ git pull, then run:
          ┌─────────────┴─────────────┐
          ▼                           ▼
   ┌─────────────┐             ┌─────────────┐
   │  Terraform  │             │   Ansible   │
   │ provisions  │             │ configures  │
   └──────┬──────┘             └──────┬──────┘
          │  Proxmox API              │  SSH
          ▼                           ▼
   ┌───────────────────────────────────────┐
   │            Proxmox VE host             │
   │   VMs/CTs ← created → then configured  │
   └───────────────────────────────────────┘
```

**Division of labor:**
- **Terraform** answers "do these VMs exist with this CPU/RAM/disk/IP?"
- **Ansible** answers "is the right software installed and configured inside?"
- **Semaphore** runs both for you, remotely.

## Repository map

```
PROXMOX_API.md           ← START HERE: API token setup, step by step
main.yml                 ← root convenience playbook (imports the baseline)
terraform/               ← provisioning (versions, variables, main, outputs)
ansible/
  ansible.cfg
  baseline/
    homelab.proxmox.yml  ← dynamic inventory (pulls hosts from Proxmox)
    main.yml             ← ubuntu → tailscale → services
    ubuntu/              ← base OS prep, user, hardening
    tailscale/           ← mesh VPN
    services/            ← gitea, media, paperless, uptimekuma + pihole, npm
    proxmox/             ← hypervisor-level tasks (build template, API users)
semaphore/               ← notes on remote execution
```

## Suggested service additions (and why)

Your tree already had Gitea, a media stack, Paperless, and Uptime Kuma. Two
additions make great learning material because they each introduce a concept
the others don't:

- **Pi-hole** (`services/pihole.yml`) — network-wide DNS ad-blocker. Teaches
  UDP/TCP port mapping and Linux capabilities (`NET_ADMIN`, binding port 53).
- **Nginx Proxy Manager** (`services/npm.yml`) — GUI reverse proxy with
  one-click Let's Encrypt. Teaches reverse proxying and TLS, and ties every
  other service behind clean hostnames instead of port numbers.

Other good candidates if you want more: **Vaultwarden** (password manager —
secrets handling), **Prometheus + Grafana** (metrics — multi-service wiring),
**Authentik** (SSO — auth flows).

## Quick start

```bash
# 1. Set up API access (read this first)
#    -> see PROXMOX_API.md

# 2. Build the cloud-init template Terraform clones (once)
ansible-playbook ansible/baseline/proxmox/main.yml -i 'pve.lan,' -u root

# 3. Provision VMs
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit, or use TF_VAR_* env vars
terraform init && terraform apply

# 4. Configure them
cd ..
export PROXMOX_TOKEN="<ansible token secret>"
ansible-playbook main.yml --ask-vault-pass
```

## Prerequisites

- A running Proxmox VE node you can reach.
- Terraform ≥ 1.7, Ansible (`pip install ansible proxmoxer requests`).
- Collections: `ansible-galaxy collection install community.proxmox community.docker community.general ansible.posix`.


