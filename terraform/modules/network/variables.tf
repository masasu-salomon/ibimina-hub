variable "name_prefix" {
  description = "Prefix for resource names, e.g. ibimina-hub-dev."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the network."
  type        = string
}

variable "vnet_cidr" {
  description = "Address space of the virtual network."
  type        = string

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "vnet_cidr must be a valid CIDR block, e.g. 10.20.0.0/16."
  }
}

variable "public_subnet_cidr" {
  description = "Subnet for the bastion host. Must sit inside vnet_cidr."
  type        = string

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "public_subnet_cidr must be a valid CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "Subnet for the app VM (no public IPs). Must sit inside vnet_cidr."
  type        = string

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "private_subnet_cidr must be a valid CIDR block."
  }
}

variable "database_subnet_cidr" {
  description = "Subnet delegated to PostgreSQL Flexible Server. Must sit inside vnet_cidr."
  type        = string

  validation {
    condition     = can(cidrhost(var.database_subnet_cidr, 0))
    error_message = "database_subnet_cidr must be a valid CIDR block."
  }
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
