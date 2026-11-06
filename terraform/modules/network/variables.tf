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

variable "subnet_cidr" {
  description = "Address range of the app subnet. Must sit inside vnet_cidr."
  type        = string

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block, e.g. 10.20.1.0/24."
  }
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
