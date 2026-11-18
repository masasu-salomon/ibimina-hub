output "vm_id" {
  description = "ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "public_ip" {
  description = "Static public IP of the VM, or null when it has none."
  value       = var.public_ip_enabled ? azurerm_public_ip.this[0].ip_address : null
}

output "private_ip" {
  description = "Private IP of the VM inside its subnet."
  value       = azurerm_network_interface.this.private_ip_address
}

output "nic_id" {
  description = "ID of the VM's network card (the load balancer joins it to its backend pool)."
  value       = azurerm_network_interface.this.id
}

output "nic_ip_configuration_name" {
  description = "Name of the NIC's IP configuration."
  value       = "primary"
}

output "admin_username" {
  description = "Login user on the VM."
  value       = azurerm_linux_virtual_machine.this.admin_username
}

output "principal_id" {
  description = "Object ID of the VM's managed identity, or null when it has none."
  value       = var.identity_enabled ? azurerm_linux_virtual_machine.this.identity[0].principal_id : null
}
