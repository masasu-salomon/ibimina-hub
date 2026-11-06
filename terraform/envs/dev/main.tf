# The dev environment of Ibimina Hub: one resource group holding the network,
# its firewall and one VM. Each piece is a module in ../../modules, so a
# staging or prod environment is another folder with different variable values.

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

  # The key can be passed directly (CI, remote runs) or read from a file (laptop).
  ssh_public_key = coalesce(var.ssh_public_key, try(file(pathexpand(var.ssh_public_key_path)), null))
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
  tags                = local.tags
}

module "security" {
  source = "../../modules/security"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_id
  app_port            = var.app_port
  admin_cidrs         = var.admin_cidrs
  app_allowed_cidrs   = var.app_allowed_cidrs
  tags                = local.tags
}

module "compute" {
  source = "../../modules/compute"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_id
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_key      = local.ssh_public_key
  os_disk_size_gb     = var.os_disk_size_gb
  tags                = local.tags

  # Do not boot the VM until its subnet is behind the NSG.
  depends_on = [module.security]
}
