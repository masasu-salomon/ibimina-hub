output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "public_subnet_id" {
  description = "ID of the public (bastion) subnet."
  value       = azurerm_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private (app) subnet."
  value       = azurerm_subnet.app.id
}

output "database_subnet_id" {
  description = "ID of the delegated database subnet."
  value       = azurerm_subnet.database.id
}

output "postgres_private_dns_zone_id" {
  description = "Private DNS zone the database registers in."
  value       = azurerm_private_dns_zone.postgres.id
}
