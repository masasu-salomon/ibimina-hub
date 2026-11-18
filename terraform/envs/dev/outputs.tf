# Read by Ansible's dynamic inventory (ansible/inventory/terraform_inventory.py)
# and by the CD pipeline through `terraform output -json`. Renaming one breaks
# that handoff.

output "app_url" {
  description = "Public URL of the API (through the load balancer)."
  value       = "http://${module.loadbalancer.fqdn}"
}

output "health_url" {
  description = "Health check URL the load balancer probes."
  value       = "http://${module.loadbalancer.fqdn}/health"
}

output "lb_public_ip" {
  description = "Public IP of the load balancer."
  value       = module.loadbalancer.public_ip
}

output "bastion_public_ip" {
  description = "Public IP of the bastion (jumpbox)."
  value       = module.bastion.public_ip
}

output "app_private_ip" {
  description = "Private IP of the app VM; reach it through the bastion."
  value       = module.app_vm.private_ip
}

output "ssh_user" {
  description = "User Ansible logs in as on both VMs."
  value       = module.app_vm.admin_username
}

output "ssh_command" {
  description = "How to log in to the app VM through the bastion."
  value       = "ssh -J ${module.app_vm.admin_username}@${module.bastion.public_ip} ${module.app_vm.admin_username}@${module.app_vm.private_ip}"
}

output "app_port" {
  description = "Port the API listens on, on the app VM."
  value       = var.app_port
}

output "admin_cidrs" {
  description = "Addresses allowed to SSH into the bastion."
  value       = var.admin_cidrs
}

output "public_subnet_cidr" {
  description = "Bastion subnet; the only source the app VM accepts SSH from."
  value       = var.public_subnet_cidr
}

output "acr_name" {
  description = "Name of the container registry."
  value       = module.registry.name
}

output "acr_login_server" {
  description = "Registry host the app image is pushed to and pulled from."
  value       = module.registry.login_server
}

output "database_fqdn" {
  description = "Private host name of PostgreSQL (resolves inside the VNet only)."
  value       = module.database.fqdn
}

output "database_url" {
  description = "Connection URL for the app. Sensitive: shown only with terraform output -raw database_url."
  value       = module.database.connection_url
  sensitive   = true
}

output "tenant_id" {
  description = "Entra ID tenant, used by the app VM to exchange its identity token for an ACR token."
  value       = data.azurerm_client_config.current.tenant_id
}

output "resource_group_name" {
  description = "Resource group holding everything (delete it to remove all of it)."
  value       = azurerm_resource_group.this.name
}

output "bastion_nsg_name" {
  description = "NSG that CD adds its temporary SSH rule to."
  value       = module.security.public_nsg_name
}

output "vnet_id" {
  description = "ID of the virtual network."
  value       = module.network.vnet_id
}
