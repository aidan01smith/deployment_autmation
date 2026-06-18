# Terraform — Proxmox provisioning

This directory **creates the VMs**. It does not configure what runs inside them
— that is Ansible's job (see `../ansible`). Clean separation of concerns:

- **Terraform = provisioning** (does the VM exist, with this CPU/RAM/disk/IP?)
- **Ansible = configuration** (is the right software installed and configured?)

## Files

| File | Purpose |
|------|---------|
| `versions.tf` | Pins Terraform + the `bpg/proxmox` provider; optional remote state |
| `variables.tf` | All inputs (credentials, the `vms` map, network defaults) |
| `main.tf` | Provider config + the VM resource, created once per entry in `vms` |
| `outputs.tf` | Emits `name -> IP` and `name -> VMID` after apply |
| `terraform.tfvars.example` | Template for your real (gitignored) values |

## Why bpg over telmate

`bpg/proxmox` is the actively maintained provider in 2026 with full API
coverage and clean cloud-init handling. `telmate/proxmox` still works but lags
on features and bug fixes.

## Workflow

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit, or use TF_VAR_* env vars
terraform init      # downloads the provider into .terraform/
terraform fmt       # canonical formatting (run before committing)
terraform validate  # static checks
terraform plan      # dry run: shows what WOULD change, changes nothing
terraform apply     # reconciles reality to your config (asks to confirm)
terraform output    # prints the IPs Ansible needs
terraform destroy   # tears it all down
```

## Mental model

You declare the **desired end state**. Terraform records what it built in
`terraform.tfstate`, diffs that against your `.tf` files on every plan, and
issues only the API calls needed to close the gap. Resources reference each
other (e.g. cloud-init reads `var.template_vm_id`) and those references build
an implicit dependency graph that controls ordering — you never sequence calls
by hand.

## The template prerequisite

Terraform **clones** VM `9000`; it does not build it. Create that cloud-init
template once (by hand or with Packer) — see `../README.md`. Without it,
`apply` fails immediately because there is nothing to clone.

