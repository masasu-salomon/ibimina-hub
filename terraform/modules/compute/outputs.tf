output "vm_id" {
  description = "ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "public_ip" {
  description = "Static public IP of the VM."
  value       = azurerm_public_ip.this.ip_address
}

output "private_ip" {
  description = "Private IP of the VM inside the subnet."
  value       = azurerm_network_interface.this.private_ip_address
}

output "admin_username" {
  description = "Login user on the VM."
  value       = azurerm_linux_virtual_machine.this.admin_username
}
