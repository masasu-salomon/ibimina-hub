# Network security groups: one stateful allow-list per subnet. Replies to an
# allowed inbound connection go back out automatically, so no outbound rules.
#
#   public NSG   (bastion subnet)
#     100  SSH 22 from admin_cidrs only (CD adds a temporary /32 for its runner)
#     4000 deny everything else
#
#   private NSG  (app subnet)
#     100  SSH 22 from the bastion subnet only - the app VM is never reachable on SSH
#          from the internet
#     110  app port from app_allowed_cidrs - the Standard load balancer keeps the
#          caller's IP, so the NSG sees internet addresses, not the LB's
#     120  app port from the AzureLoadBalancer tag (health probes)
#     4000 deny everything else
#
#   database NSG (delegated Postgres subnet)
#     100  Postgres 5432 from the app subnet only
#     4000 deny everything else
#
# Lower priority number = checked first. Rule 4000 is written out so the intent
# is visible, and it also overrides Azure's default "allow anything inside the VNet".

locals {
  nsgs = {
    public   = var.public_subnet_id
    private  = var.private_subnet_id
    database = var.database_subnet_id
  }

  rules = {
    public_ssh_admin = {
      nsg         = "public"
      name        = "AllowSSHFromAdmin"
      priority    = 100
      port        = "22"
      sources     = var.admin_cidrs
      service_tag = null
    }
    private_ssh_bastion = {
      nsg         = "private"
      name        = "AllowSSHFromBastion"
      priority    = 100
      port        = "22"
      sources     = [var.public_subnet_cidr]
      service_tag = null
    }
    private_app = {
      nsg         = "private"
      name        = "AllowAppFromClients"
      priority    = 110
      port        = tostring(var.app_port)
      sources     = var.app_allowed_cidrs
      service_tag = null
    }
    private_lb_probe = {
      nsg         = "private"
      name        = "AllowLoadBalancerProbe"
      priority    = 120
      port        = tostring(var.app_port)
      sources     = null
      service_tag = "AzureLoadBalancer"
    }
    database_postgres = {
      nsg         = "database"
      name        = "AllowPostgresFromApp"
      priority    = 100
      port        = "5432"
      sources     = [var.private_subnet_cidr]
      service_tag = null
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.nsgs

  name                = "${var.name_prefix}-${each.key}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "allow" {
  for_each = local.rules

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefixes     = each.value.sources
  source_address_prefix       = each.value.service_tag
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.value.nsg].name
}

resource "azurerm_network_security_rule" "deny_all_inbound" {
  for_each = local.nsgs

  name                        = "DenyAllInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.key].name
}

# An NSG protects nothing until it is attached. Attaching it to the subnet covers
# every machine placed in the subnet, now and later.
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsgs

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
