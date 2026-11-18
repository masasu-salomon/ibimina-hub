# Managed PostgreSQL (Azure Database for PostgreSQL Flexible Server) with private
# access only: it gets an address inside the delegated database subnet, has no
# public endpoint, and its NSG only lets the app subnet in on 5432.
# Azure handles patching and daily backups (7 days, point-in-time restore).

resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "-_"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}

resource "azurerm_postgresql_flexible_server" "this" {
  #checkov:skip=CKV_AZURE_136:Geo-redundant backup doubles the cost; a course environment accepts losing data if the whole region fails.
  #checkov:skip=CKV2_AZURE_57:Private access is used through VNet integration (delegated subnet), which is the private-endpoint alternative for Flexible Server.
  name                = "${var.name_prefix}-pg"
  location            = var.location
  resource_group_name = var.resource_group_name
  version             = var.postgres_version
  sku_name            = var.sku_name
  storage_mb          = var.storage_mb
  tags                = var.tags

  administrator_login    = var.admin_username
  administrator_password = random_password.admin.result

  # Private access: no public endpoint at all.
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = false

  lifecycle {
    # Azure picks a zone when none is given; do not fight it on later plans.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Keep TLS mandatory and log connections, so failed logins show up in the server logs.
resource "azurerm_postgresql_flexible_server_configuration" "settings" {
  for_each = {
    require_secure_transport = "on"
    log_connections          = "on"
    log_disconnections       = "on"
    log_checkpoints          = "on"
  }

  server_id = azurerm_postgresql_flexible_server.this.id
  name      = each.key
  value     = each.value
}
