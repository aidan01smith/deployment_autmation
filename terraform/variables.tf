# variables.tf
#
# Input variables are the "function arguments" of a Terraform module. They let
# you keep secrets and per-environment values out of main.tf. Values come from
# (in order of precedence): -var flags, *.auto.tfvars, terraform.tfvars, then
# environment variables named TF_VAR_<name>, then the default below.

variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://pve.lan:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "API token in the form user@realm!tokenid=uuid-secret"
  type        = string
  sensitive   = true # masks the value in plan/apply output and state echoes
}

variable "proxmox_node" {
  description = "Name of the Proxmox node to deploy onto (see Datacenter view)"
  type        = string
  default     = "pve"
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for self-signed homelab certs)"
  type        = bool
  default     = true
}

# The cloud-init template VMs are cloned from. You build this once by hand or
# with Packer (see TAILSCALE.md / README). Terraform clones it, never builds it.
variable "template_vm_id" {
  description = "VMID of the Ubuntu cloud-init template to clone"
  type        = number
  default     = 9000
}

variable "ci_user" {
  description = "Default cloud-init username created inside each guest"
  type        = string
  default     = "ansible"
}

variable "ci_ssh_public_keys" {
  description = "SSH public keys injected into every guest via cloud-init"
  type        = list(string)
}

variable "gateway" {
  description = "Default gateway handed to guests via cloud-init"
  type        = string
  default     = "192.168.1.1"
}

variable "bridge" {
  description = "Proxmox network bridge to attach NICs to"
  type        = string
  default     = "vmbr0"
}

variable "datastore" {
  description = "Storage pool for guest disks"
  type        = string
  default     = "local-lvm"
}

# The heart of the config: a map describing every VM to create. Adding a guest
# is a data change here, not new resource blocks. The map key becomes the name.
variable "vms" {
  description = "Map of VMs to create, keyed by hostname"
  type = map(object({
    vmid    = number
    cores   = number
    memory  = number # MiB
    disk    = number # GiB
    ip      = string # last octet only; combined with subnet below
    tags    = list(string)
  }))
  default = {
    docker = { vmid = 110, cores = 4, memory = 8192, disk = 40, ip = "110", tags = ["services", "docker"] }
    media  = { vmid = 111, cores = 2, memory = 4096, disk = 80, ip = "111", tags = ["services", "media"] }
  }
}

variable "subnet_prefix" {
  description = "First three octets of the LAN, no trailing dot"
  type        = string
  default     = "192.168.1"
}

variable "subnet_cidr" {
  description = "CIDR suffix for guest IPs"
  type        = number
  default     = 24
}

