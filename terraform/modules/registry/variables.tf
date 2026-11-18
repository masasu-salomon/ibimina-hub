variable "name_prefix" {
  description = "Prefix for the registry name (hyphens are removed: ACR names are alphanumeric)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the registry."
  type        = string
}

variable "sku" {
  description = "Registry SKU."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard or Premium."
  }
}

variable "pull_principal_ids" {
  description = "Principals (object IDs) that may pull, keyed by a static name."
  type        = map(string)
  default     = {}
}

variable "push_principal_ids" {
  description = "Principals (object IDs) that may push, keyed by a static name."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
