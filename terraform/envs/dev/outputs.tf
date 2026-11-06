# Read by Ansible's dynamic inventory (ansible/inventory/terraform_inventory.py)
# through `terraform output -json`. Renaming one breaks that handoff.

output "public_ip" {
  description = "Public IP of the app server."
  value       = module.compute.public_ip
}

output "private_ip" {
  description = "Private IP of the app server inside the subnet."
  value       = module.compute.private_ip
}

output "ssh_user" {
  description = "User Ansible logs in as."
  value       = module.compute.admin_username
}

output "app_port" {
  description = "Port the API is published on."
  value       = var.app_port
}

output "app_url" {
  description = "Health check URL once Ansible has deployed the app."
  value       = "http://${module.compute.public_ip}:${var.app_port}/health"
}

output "ssh_command" {
  description = "How to log in to the server."
  value       = "ssh ${module.compute.admin_username}@${module.compute.public_ip}"
}

output "resource_group_name" {
  description = "Resource group holding everything (delete it to remove all of it)."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "ID of the resource group."
  value       = azurerm_resource_group.this.id
}

output "vnet_id" {
  description = "ID of the virtual network."
  value       = module.network.vnet_id
}

output "subnet_id" {
  description = "ID of the app subnet."
  value       = module.network.subnet_id
}

output "nsg_id" {
  description = "ID of the network security group."
  value       = module.security.nsg_id
}

output "vm_id" {
  description = "ID of the virtual machine."
  value       = module.compute.vm_id
}
