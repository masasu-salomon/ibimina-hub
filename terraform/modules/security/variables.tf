variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the NSGs."
  type        = string
}

variable "public_subnet_id" {
  description = "Bastion subnet the public NSG is attached to."
  type        = string
}

variable "private_subnet_id" {
  description = "App subnet the private NSG is attached to."
  type        = string
}

variable "database_subnet_id" {
  description = "Database subnet the database NSG is attached to."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR of the bastion subnet; the only source allowed to SSH into the app subnet."
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR of the app subnet; the only source allowed to reach Postgres."
  type        = string
}

variable "app_port" {
  description = "Port the API listens on."
  type        = number
}

variable "admin_cidrs" {
  description = "CIDRs allowed to SSH into the bastion, e.g. [\"41.186.0.168/32\"]."
  type        = list(string)

  validation {
    condition     = length(var.admin_cidrs) > 0 && alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "admin_cidrs needs at least one valid CIDR, and SSH must never be open to 0.0.0.0/0."
  }
}

variable "app_allowed_cidrs" {
  description = "CIDRs allowed to reach the API port (through the load balancer)."
  type        = list(string)

  validation {
    condition     = length(var.app_allowed_cidrs) > 0 && alltrue([for c in var.app_allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "app_allowed_cidrs needs at least one valid CIDR."
  }
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
