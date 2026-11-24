# Bootstrap: the two things every other Terraform run and the CD pipeline depend on.
#
#   1. Remote state  - a storage account + container that holds envs/*/terraform.tfstate,
#                      with blob leases as the lock, so the laptop and the pipeline
#                      see the same state and can never apply at the same time.
#   2. CD identity   - an Entra ID app + service principal that GitHub Actions logs in
#                      as through OIDC (federated credentials). No client secret exists,
#                      so there is nothing to leak or rotate.
#
# Applied once, by a person with Owner on the subscription. Day-to-day changes go
# through envs/dev.

data "azurerm_client_config" "current" {}

locals {
  tags = {
    project    = var.project_name
    managed_by = "terraform"
    layer      = "bootstrap"
    repository = var.github_repository
  }
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "state" {
  name     = "${var.project_name}-tfstate-rg"
  location = var.location
  tags     = local.tags
}

# ---------- 1. Remote state ----------
resource "azurerm_storage_account" "state" {
  #checkov:skip=CKV_AZURE_33:Queue service is not used; only the blob container holds state.
  #checkov:skip=CKV_AZURE_59:Public endpoint stays on so GitHub-hosted runners (no fixed IPs) can reach state; shared keys are off and access is Entra ID + RBAC only.
  #checkov:skip=CKV_AZURE_206:LRS is enough for a course environment; state is also versioned (blob versioning + soft delete).
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed keys are accepted; a customer-managed key needs a Key Vault we do not run.
  #checkov:skip=CKV2_AZURE_33:No private endpoint: GitHub-hosted runners are outside the VNet.
  #checkov:skip=CKV2_AZURE_41:Shared keys are disabled, so no SAS tokens can be issued at all.
  name                     = "ibiminatfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  local_user_enabled              = false
  default_to_oauth_authentication = true

  blob_properties {
    # Every apply writes a new version; a bad apply can be undone from history.
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  sas_policy {
    expiration_period = "01.00:00:00"
  }

  tags = local.tags
}

resource "azurerm_storage_container" "state" {
  #checkov:skip=CKV2_AZURE_21:Blob read logging needs a Log Analytics workspace (paid ingestion). Access is Entra ID + RBAC only and visible in the Azure activity log; accepted risk for a course environment.
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# Whoever runs bootstrap also needs data-plane access to the container they just made.
resource "azurerm_role_assignment" "operator_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------- 2. CD identity (GitHub Actions OIDC) ----------
resource "azuread_application" "cd" {
  display_name = "${var.project_name}-github-cd"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "cd" {
  client_id = azuread_application.cd.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

# GitHub's token for a job that runs in the "production" environment of this repo.
# Every CD job that touches Azure runs in that environment, which only main can use.
# The subject uses GitHub's immutable form (owner@id/repo@id), so a renamed or
# re-created repo with the same name can never reuse this trust.
resource "azuread_application_federated_identity_credential" "production" {
  #checkov:skip=CKV_AZURE_249:False positive. The subject is pinned to one repo and environment; Checkov's repo regex does not accept GitHub's immutable owner@id/name@id form.
  application_id = azuread_application.cd.id
  display_name   = "github-${var.github_environment}"
  description    = "GitHub Actions jobs in the ${var.github_environment} environment of ${var.github_repository}"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repository_immutable}:environment:${var.github_environment}"
}

# Least privilege for the pipeline. Everything else it needs is granted next to
# the resource it touches, in envs/dev (AcrPush on the registry, NSG rule rights
# on the bastion's NSG).
resource "azurerm_role_assignment" "cd_state" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.cd.object_id
}

# Read-only view of the subscription so `terraform plan` can refresh every resource.
resource "azurerm_role_assignment" "cd_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.cd.object_id
}
