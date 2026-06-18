# PROXMOX_API.md — Using the Proxmox API for remote, automated deployments

This is the standalone guide you asked for: how to set up Proxmox so Terraform,
Ansible, and Semaphore can drive it **remotely with an API token + secret**,
without ever using the root password. Follow it once.

---

## 0. Mental model

Proxmox exposes a full REST API at `https://<host>:8006/api2/json/`. Every tool
here talks to that API:

- **Terraform** (`bpg/proxmox` provider) → creates/destroys VMs.
- **Ansible** (`community.proxmox` collection) → dynamic inventory + host tasks.
- **Semaphore** → runs the above on demand/remotely.

Authentication is via an **API token**, formatted as:

```
USER@REALM!TOKENID=SECRET
e.g.  terraform@pve!tf=00000000-0000-0000-0000-000000000000
```

The secret half is shown **exactly once** at creation — save it immediately.

---

## 1. Create dedicated API users (not root)

On the Proxmox host shell (or Datacenter → Permissions → Users in the GUI):

```bash
# Create users in the PVE realm (Proxmox-managed, not Linux PAM)
pveum user add terraform@pve --comment "Terraform provisioning"
pveum user add ansible@pve   --comment "Ansible inventory + config"
```

> The `proxmox/security.yml` playbook in this repo does exactly this — you can
> run it instead of typing the commands.

---

## 2. Grant least-privilege roles

```bash
# Terraform needs to create/manage VMs and allocate storage:
pveum acl modify / --users terraform@pve --roles PVEVMAdmin

# Ansible's inventory only needs to read:
pveum acl modify / --users ansible@pve --roles PVEAuditor
```

For tighter scoping you can create a custom role with only the privileges you
need (`VM.Allocate`, `VM.Clone`, `VM.Config.*`, `Datastore.AllocateSpace`,
`Sys.Audit`, etc.):

```bash
pveum role add TerraformProv -privs "VM.Allocate VM.Clone VM.Config.Disk \
  VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Cloudinit \
  VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit SDN.Use"
pveum acl modify / --users terraform@pve --roles TerraformProv
```

---

## 3. Generate the API tokens

```bash
# --privsep 0 means the token inherits the user's privileges (simplest).
# Set --privsep 1 and assign ACLs to the token itself for finer control.
pveum user token add terraform@pve tf --privsep 0
pveum user token add ansible@pve  ansible --privsep 0
```

Each command prints a table containing the **secret UUID**. Copy it now:

```
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
├──────────────┼──────────────────────────────────────┤
│ full-tokenid │ terraform@pve!tf                     │
│ value        │ 00000000-0000-0000-0000-000000000000 │  <-- the SECRET
└──────────────┴──────────────────────────────────────┘
```

Your full token string is `terraform@pve!tf=00000000-...-000000000000`.

---

## 4. Hand the credentials to each tool

**Terraform** — export as an env var (never commit):

```bash
export TF_VAR_proxmox_endpoint="https://pve.lan:8006/"
export TF_VAR_proxmox_api_token="terraform@pve!tf=00000000-0000-0000-0000-000000000000"
cd terraform && terraform init && terraform plan
```

**Ansible dynamic inventory** — the secret is read from `PROXMOX_TOKEN`
(see `homelab.proxmox.yml`):

```bash
export PROXMOX_TOKEN="11111111-1111-1111-1111-111111111111"
ansible-inventory -i ansible/baseline/homelab.proxmox.yml --graph
```

**Ansible playbook tasks** (when calling proxmox modules directly) use:

```yaml
api_host: pve.lan
api_user: ansible@pve
api_token_id: ansible
api_token_secret: "{{ vault_proxmox_token_secret }}"   # ansible-vault
```

---

## 5. Self-signed TLS

Homelab Proxmox uses a self-signed cert. Each tool needs to be told to skip
verification:

- Terraform: `insecure = true` (already wired to `var.proxmox_insecure`).
- Ansible inventory: `validate_certs: false`.
- Ansible modules: `validate_certs: false`.

For a "real" setup, put a proper cert on Proxmox (e.g. via Let's Encrypt /
the NPM service in this repo) and flip these to verify.

---

## 6. Verify end to end

```bash
# Can the token even reach the API? (raw curl)
curl -sk -H "Authorization: PVEAPIToken=terraform@pve!tf=00000000-...-000" \
  https://pve.lan:8006/api2/json/version | jq

# Terraform sees the node:
cd terraform && terraform plan        # should show VMs to be created

# Ansible sees the guests:
ansible-inventory -i ansible/baseline/homelab.proxmox.yml --graph
```

---

## 7. Remote execution via Semaphore

Once tokens work locally, move execution off your laptop:

1. Run Semaphore as a container.
2. Store `PROXMOX_TOKEN`, `TF_VAR_proxmox_api_token`, the Vault password and
   SSH key as Semaphore secrets/environment.
3. Point a Repository at your git copy of this repo.
4. Create two task templates: one running Terraform in `terraform/`, one
   running `ansible-playbook ansible/baseline/main.yml`.
5. Trigger via the UI, a schedule, or the REST API:

```bash
curl -X POST https://semaphore.lan/api/project/1/tasks \
  -H "Authorization: Bearer $SEMAPHORE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"template_id": 2}'
```

That POST is your fully remote, headless deployment trigger.

---

## Security checklist

- [ ] No root@pam token in use — dedicated `terraform@pve` / `ansible@pve`.
- [ ] Token secrets only in env vars or `ansible-vault`, never in git.
- [ ] `.gitignore` covers `*.tfvars`, `*.tfstate*`, `tailscale_oauth_key.yml`.
- [ ] Least-privilege roles (or custom roles) assigned.
- [ ] Real TLS cert once you outgrow the homelab phase.
- [ ] Rotate tokens periodically (`pveum user token remove` + re-add).
