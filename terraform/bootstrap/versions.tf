terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # The bootstrap layer creates the remote state store, so its own state has to
  # live somewhere else: on the laptop of whoever runs it (Git ignores it).
  # It changes rarely and only holds names and IDs, no secrets.
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id

  # Storage data-plane calls (the tfstate container) use Entra ID, not account keys.
  storage_use_azuread = true
}

provider "azuread" {}
