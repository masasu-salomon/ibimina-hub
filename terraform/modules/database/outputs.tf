output "server_id" {
  description = "ID of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "fqdn" {
  description = "Private host name of the server (resolves inside the VNet only)."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "Name of the app database."
  value       = azurerm_postgresql_flexible_server_database.app.name
}

output "admin_username" {
  description = "Administrator login."
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "connection_url" {
  description = "postgres:// URL for the app (TLS required)."
  value       = "postgres://${azurerm_postgresql_flexible_server.this.administrator_login}:${urlencode(random_password.admin.result)}@${azurerm_postgresql_flexible_server.this.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}?sslmode=require"
  sensitive   = true
}
