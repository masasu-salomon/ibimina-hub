output "nsg_ids" {
  description = "IDs of the NSGs, keyed by subnet role (public, private, database)."
  value       = { for k, nsg in azurerm_network_security_group.this : k => nsg.id }
}

output "public_nsg_name" {
  description = "Name of the bastion NSG. CD adds and removes its runner's SSH rule here."
  value       = azurerm_network_security_group.this["public"].name
}

output "public_nsg_id" {
  description = "ID of the bastion NSG."
  value       = azurerm_network_security_group.this["public"].id
}
