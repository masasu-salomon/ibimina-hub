# Private container registry (Azure Container Registry). CD pushes images here;
# the app VM pulls them with its managed identity. The admin user (a shared
# username/password) stays off: every pull and push is tied to an identity.

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_container_registry" "this" {
  #checkov:skip=CKV_AZURE_139:Public endpoint needed for GitHub-hosted runners; anonymous pull and the admin user are off, so every call needs an Entra ID identity.
  #checkov:skip=CKV_AZURE_163:Image vulnerability scanning runs in CI with Trivy before every push (Defender for Containers is a paid add-on).
  #checkov:skip=CKV_AZURE_164:Content trust needs the Premium SKU; images are only pushed by the CD identity after Trivy passes.
  #checkov:skip=CKV_AZURE_165:Geo-replication needs Premium; one region is enough for this environment.
  #checkov:skip=CKV_AZURE_166:Quarantine needs Premium; the Trivy gate in CD blocks images with fixable HIGH/CRITICAL CVEs before push.
  #checkov:skip=CKV_AZURE_167:Retention policy needs Premium; untagged manifests are rare because every push is tagged with a commit SHA.
  #checkov:skip=CKV_AZURE_233:Zone redundancy needs Premium.
  #checkov:skip=CKV_AZURE_237:Dedicated data endpoints need Premium.
  name                = "${replace(var.name_prefix, "-", "")}${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  tags                = var.tags

  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
}

# Pull only, for identities that run images (the app VM).
resource "azurerm_role_assignment" "pull" {
  for_each = var.pull_principal_ids

  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = each.value
}

# Push (and pull), for the CD pipeline.
resource "azurerm_role_assignment" "push" {
  for_each = var.push_principal_ids

  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = each.value
}
