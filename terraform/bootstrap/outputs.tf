# Copy these into GitHub (Settings -> Secrets and variables -> Actions) and into
# the backend block of envs/dev/versions.tf. None of them is a secret: OIDC
# needs no password.

output "state_resource_group_name" {
  description = "Resource group of the state store."
  value       = azurerm_resource_group.state.name
}

output "state_storage_account_name" {
  description = "Storage account that holds Terraform state."
  value       = azurerm_storage_account.state.name
}

output "state_container_name" {
  description = "Blob container that holds Terraform state."
  value       = azurerm_storage_container.state.name
}

output "azure_client_id" {
  description = "AZURE_CLIENT_ID for GitHub Actions."
  value       = azuread_application.cd.client_id
}

output "azure_tenant_id" {
  description = "AZURE_TENANT_ID for GitHub Actions."
  value       = data.azurerm_client_config.current.tenant_id
}

output "azure_subscription_id" {
  description = "AZURE_SUBSCRIPTION_ID for GitHub Actions."
  value       = data.azurerm_client_config.current.subscription_id
}

output "cd_principal_object_id" {
  description = "Object ID of the CD service principal; envs/dev grants it AcrPush and NSG rights."
  value       = azuread_service_principal.cd.object_id
}
