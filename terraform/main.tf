# main.tf
#
# This is where infrastructure is declared. Terraform reads the desired state
# here, compares it to recorded state, and computes the minimal set of API
# calls to reconcile them. You describe the *what*; Terraform figures out the
# *how* and the *order* (via an implicit dependency graph built from references).

# ----------------------------------------------------------------------------
# Provider configuration
# ----------------------------------------------------------------------------
# The provider block configures the plugin declared in versions.tf. Everything
# here is read from variables so no secret is ever committed.
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # SSH is only needed for a few operations (uploading snippets, some file
  # tasks). For plain clone-from-template + cloud-init it can be omitted.
  # When using an API token you must give ssh an explicit username because
  # there's no password to inherit.
  ssh {
    agent    = true
    username = "root"
  }
}

# ----------------------------------------------------------------------------
# Cloud-init network data
# ----------------------------------------------------------------------------
# locals are computed values reused below. Here we turn the simple "last octet"
# from var.vms into a full CIDR address per VM.
locals {
  vm_addresses = {
    for name, cfg in var.vms :
    name => "${var.subnet_prefix}.${cfg.ip}/${var.subnet_cidr}"
  }
}

# ----------------------------------------------------------------------------
# Virtual machines
# ----------------------------------------------------------------------------
# for_each iterates over the var.vms map, creating one VM per entry. Using
# for_each (not count) keys each resource by name, so removing "media" later
# destroys only that VM instead of renumbering everything.
resource "proxmox_virtual_environment_vm" "guest" {
  for_each = var.vms

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vmid
  tags      = each.value.tags

  # Clone from the prebuilt cloud-init template rather than installing an OS.
  clone {
    vm_id = var.template_vm_id
    full  = true # full clone = independent disk, not a linked/CoW clone
  }

  agent {
    enabled = true # requires qemu-guest-agent inside the template
  }

  cpu {
    cores = each.value.cores
    type  = "host" # passes host CPU flags through; best performance
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = each.value.disk
    discard      = "on"
  }

  network_device {
    bridge = var.bridge
  }

  # cloud-init: the bridge between Terraform (provisioning) and a usable guest.
  # This sets the hostname, network, user and SSH keys on first boot so that
  # Ansible can immediately connect over SSH afterwards.
  initialization {
    ip_config {
      ipv4 {
        address = local.vm_addresses[each.key]
        gateway = var.gateway
      }
    }

    user_account {
      username = var.ci_user
      keys     = var.ci_ssh_public_keys
    }
  }

  # lifecycle blocks tune how Terraform treats drift. The Proxmox API reports
  # network MAC changes on every clone, which would otherwise show as spurious
  # diffs; ignore them so plans stay clean.
  lifecycle {
    ignore_changes = [network_device]
  }
}

