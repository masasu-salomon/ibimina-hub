# Private network for one environment: a virtual network (Azure's VPC) split
# into three subnets, each with one job:
#
#   public    the bastion (jumpbox) - the only VM with its own public IP
#   private   the app VM - no public IP; reached by SSH through the bastion and by
#             web traffic through the load balancer
#   database  delegated to PostgreSQL Flexible Server, so the database has a private
#             address only and is never reachable from the internet
#
# Azure routes between subnets of one VNet automatically, so there are no route
# tables here; the NSGs in ../security decide what may talk to what.

resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "public" {
  name                 = "${var.name_prefix}-public-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.public_subnet_cidr]
}

# Kept as "app" (its name from Formative 3) so the existing subnet is updated in
# place instead of being destroyed and recreated.
resource "azurerm_subnet" "app" {
  name                 = "${var.name_prefix}-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_subnet_cidr]
}

resource "azurerm_subnet" "database" {
  name                 = "${var.name_prefix}-db-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.database_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "postgres-flexible"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# PostgreSQL with private access resolves its host name through a private DNS
# zone linked to this VNet, so the app VM gets the private IP.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.name_prefix}.private.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.name_prefix}-postgres-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = var.tags
}
