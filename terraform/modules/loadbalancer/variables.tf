variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the load balancer."
  type        = string
}

variable "dns_label" {
  description = "DNS label of the public IP: <label>.<region>.cloudapp.azure.com. Must be unique in the region."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.dns_label))
    error_message = "dns_label must be 3-63 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "frontend_port" {
  description = "Public port users connect to."
  type        = number
  default     = 80
}

variable "backend_port" {
  description = "Port the API listens on, on the VM."
  type        = number
}

variable "health_path" {
  description = "HTTP path the health probe calls; must return 200 when the API is healthy."
  type        = string
  default     = "/health"
}

variable "backend_nics" {
  description = "NICs to put behind the load balancer, keyed by a static name."
  type = map(object({
    nic_id                = string
    ip_configuration_name = string
  }))
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
