# Private network for one environment: a virtual network (Azure's VPC) and one
# subnet inside it. Azure adds the default route to the internet for us, so there
# is no internet gateway or route table to declare (unlike AWS).

resource "azurerm_virtual_network" "this" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                 = "${var.name_prefix}-app-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_cidr]
}
