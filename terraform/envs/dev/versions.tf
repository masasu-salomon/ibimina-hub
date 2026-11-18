terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Shared, locked state in the storage account made by ../../bootstrap. The laptop
  # and the CD pipeline read the same state; a blob lease stops two applies at once.
  # Access is Entra ID only (no storage keys): locally your `az login`, in CI the
  # OIDC identity.
  backend "azurerm" {
    resource_group_name  = "ibimina-hub-tfstate-rg"
    storage_account_name = "ibiminatfstate2dl703"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}

  # null = read ARM_SUBSCRIPTION_ID from the environment, so no subscription ID
  # is ever committed.
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {}
