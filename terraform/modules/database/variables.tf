variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the server."
  type        = string
}

variable "delegated_subnet_id" {
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone (ending in .postgres.database.azure.com) linked to the VNet."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "Server size. B_Standard_B1ms is the smallest burstable size."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage in MB (32768 is the minimum)."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Days of point-in-time backups to keep (7-35)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "admin_username" {
  description = "Administrator login of the server."
  type        = string
  default     = "ibiminaadmin"
}

variable "database_name" {
  description = "Database the app uses."
  type        = string
  default     = "ibimina"
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
