# versions.tf
#
# Pins Terraform itself and every provider this configuration depends on.
# Keeping this in its own file is a community convention: it makes the
# "contract" of the module obvious and keeps main.tf focused on resources.
#
# We use the bpg/proxmox provider rather than telmate/proxmox. As of 2026 bpg
# is the actively maintained option: frequent releases, full Proxmox API
# coverage (VMs, LXC, users, ACLs, SDN, storage) and clean cloud-init support.
# Telmate is older and effectively limited to VMs/LXC.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.78" # allows 0.78.x ... 0.999, but not 1.0.0
    }
  }

}

