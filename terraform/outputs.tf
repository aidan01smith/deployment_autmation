# outputs.tf
#
# Outputs expose values after apply. They print to the terminal, are queryable
# with `terraform output`, and can be consumed by other tooling. Here we emit a
# map of hostname -> IP, which is exactly what an Ansible inventory wants.

output "vm_ip_addresses" {
  description = "Map of VM name to its assigned IPv4 address"
  value = {
    for name, vm in proxmox_virtual_environment_vm.guest :
    name => trimsuffix(local.vm_addresses[name], "/${var.subnet_cidr}")
  }
}

output "vm_ids" {
  description = "Map of VM name to its Proxmox VMID"
  value = {
    for name, vm in proxmox_virtual_environment_vm.guest :
    name => vm.vm_id
  }
}

