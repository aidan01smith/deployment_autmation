# Semaphore

[Semaphore UI](https://semaphoreui.com/) is a web UI for running Ansible
playbooks (and Terraform) on a schedule or on demand, with stored credentials,
logs, and access control. It's the "remote execution" layer for this repo:
instead of running `ansible-playbook` from your laptop, Semaphore runs it for
you from a always-on container and exposes a button + API.

## Why use it here

- Run the baseline playbook or a `terraform apply` from a browser or via its
  REST API — this is how you "remotely execute this program."
- Store the Proxmox token, Vault password, and SSH key once, as encrypted
  Semaphore secrets, instead of scattering them.
- Schedule recurring runs (nightly updates via the rolling-update play).

## Sketch of setup

1. Run Semaphore itself as a container (it's just another service — you could
   add a `services/semaphore.yml` following the same compose pattern).
2. In the UI: add a **Key Store** entry for your SSH key and the Vault
   password; add **Environment** variables for `PROXMOX_TOKEN` etc.
3. Add a **Repository** pointing at your Gitea/GitHub copy of this repo.
4. Create **Task Templates**:
   - *Provision* → runs Terraform in `terraform/`.
   - *Configure* → runs `ansible-playbook baseline/main.yml`.
5. Trigger from the UI, a schedule, or `POST /api/project/<id>/tasks`.

## Flow

```
Semaphore  --(git pull)-->  this repo
   |                          |
   |-- terraform apply -------+--> Proxmox API --> VMs created
   |-- ansible-playbook ------+--> SSH into VMs  --> configured
```

