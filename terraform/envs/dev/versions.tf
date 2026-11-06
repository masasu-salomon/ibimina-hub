terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # State stays on the laptop that runs `apply` by default (Git ignores it).
  # For shared, locked state, see "Remote state" in terraform/README.md.
}

provider "azurerm" {
  features {}

  # null = read ARM_SUBSCRIPTION_ID from the environment, so no subscription ID
  # is ever committed.
  subscription_id = var.subscription_id
}
