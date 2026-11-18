# The dev environment of Ibimina Hub. Everything lives in one resource group;
# each piece is a module in ../../modules, so staging or prod is another folder
# with different variable values.
#
#   internet --:80--> load balancer --:3000--> app VM (private subnet, no public IP)
#   admin/CD --:22--> bastion (public subnet) --:22--> app VM
#   app VM   --:5432--> PostgreSQL (delegated subnet, private access only)
#   app VM   --pull--> ACR (managed identity, AcrPull)   CD --push--> ACR (OIDC, AcrPush)

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
      repository  = "masasu-salomon/ibimina-hub"
    },
    var.extra_tags,
  )

  # The operator's key (passed directly in CI, or read from a file on a laptop),
  # plus teammates' keys and the CD deploy key.
  ssh_public_keys = distinct(compact(concat(
    [coalesce(var.ssh_public_key, try(file(pathexpand(var.ssh_public_key_path)), null))],
    var.extra_ssh_public_keys,
  )))
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  name_prefix          = local.name_prefix
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  vnet_cidr            = var.vnet_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidr  = var.private_subnet_cidr
  database_subnet_cidr = var.database_subnet_cidr
  tags                 = local.tags
}

module "security" {
  source = "../../modules/security"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  public_subnet_id    = module.network.public_subnet_id
  private_subnet_id   = module.network.private_subnet_id
  database_subnet_id  = module.network.database_subnet_id
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  app_port            = var.app_port
  admin_cidrs         = var.admin_cidrs
  app_allowed_cidrs   = var.app_allowed_cidrs
  tags                = local.tags
}

# Jumpbox: the only VM with a public IP, and only SSH from admin_cidrs reaches it.
module "bastion" {
  source = "../../modules/compute"

  name_prefix         = "${local.name_prefix}-bastion"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.public_subnet_id
  vm_size             = var.bastion_vm_size
  admin_username      = var.admin_username
  ssh_public_keys     = local.ssh_public_keys
  public_ip_enabled   = true
  os_disk_size_gb     = 30
  tags                = merge(local.tags, { role = "bastion" })

  depends_on = [module.security]
}

# App server: private subnet, no public IP, managed identity for pulling images.
module "app_vm" {
  source = "../../modules/compute"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.private_subnet_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_keys     = local.ssh_public_keys
  public_ip_enabled   = false
  identity_enabled    = true
  os_disk_size_gb     = var.os_disk_size_gb
  tags                = merge(local.tags, { role = "app" })

  # Do not boot the VM until its subnet is behind the NSG.
  depends_on = [module.security]
}

module "loadbalancer" {
  source = "../../modules/loadbalancer"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_label           = coalesce(var.dns_label, local.name_prefix)
  frontend_port       = 80
  backend_port        = var.app_port
  health_path         = "/health"
  backend_nics = {
    app = {
      nic_id                = module.app_vm.nic_id
      ip_configuration_name = module.app_vm.nic_ip_configuration_name
    }
  }
  tags = local.tags
}

module "database" {
  source = "../../modules/database"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  delegated_subnet_id = module.network.database_subnet_id
  private_dns_zone_id = module.network.postgres_private_dns_zone_id
  sku_name            = var.database_sku
  tags                = local.tags

  # The DNS zone must be linked to the VNet before the server registers in it.
  depends_on = [module.network, module.security]
}

module "registry" {
  source = "../../modules/registry"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  pull_principal_ids  = { app_vm = module.app_vm.principal_id }
  push_principal_ids  = var.cd_principal_object_id == null ? {} : { cd = var.cd_principal_object_id }
  tags                = local.tags
}

# CD opens SSH on the bastion NSG for its runner's IP for the length of one
# deploy, then removes the rule. It may change rules on this NSG and nothing else.
resource "azurerm_role_assignment" "cd_bastion_nsg" {
  count = var.cd_principal_object_id == null ? 0 : 1

  scope                = module.security.public_nsg_id
  role_definition_name = "Network Contributor"
  principal_id         = var.cd_principal_object_id
}

# ---------- Formative 3 -> Summative: keep existing resources, change them in place ----------
moved {
  from = module.compute
  to   = module.app_vm
}

moved {
  from = module.security.azurerm_network_security_group.this
  to   = module.security.azurerm_network_security_group.this["private"]
}

moved {
  from = module.security.azurerm_network_security_rule.deny_all_inbound
  to   = module.security.azurerm_network_security_rule.deny_all_inbound["private"]
}

moved {
  from = module.security.azurerm_subnet_network_security_group_association.this
  to   = module.security.azurerm_subnet_network_security_group_association.this["private"]
}
