output "id" {
  description = "ID of the registry."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Name of the registry (for az acr login --name)."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Registry host name, e.g. ibiminahubdevab12c.azurecr.io."
  value       = azurerm_container_registry.this.login_server
}
