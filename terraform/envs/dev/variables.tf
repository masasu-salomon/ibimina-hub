# Environment-specific values. Real values go in dev.tfvars (Git ignores *.tfvars);
# dev.tfvars.example shows the shape.

variable "subscription_id" {
  description = "Azure subscription ID. Leave null to use the ARM_SUBSCRIPTION_ID environment variable."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Name prefix for every resource."
  type        = string
  default     = "ibimina-hub"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name, used in resource names and tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "location" {
  description = "Azure region, e.g. southafricanorth."
  type        = string
}

variable "vm_size" {
  description = "VM size. Check what your subscription allows with: az vm list-skus --location <region> --size Standard_B --all -o table"
  type        = string

  validation {
    condition     = contains(["Standard_B1s", "Standard_B1ms", "Standard_B2s", "Standard_B2ats_v2", "Standard_B2als_v2", "Standard_B2s_v2"], var.vm_size)
    error_message = "vm_size must be one of the small burstable sizes listed in variables.tf (keeps the bill small)."
  }
}

variable "admin_username" {
  description = "Login user created on the VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key (RSA) allowed to log in."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_public_key" {
  description = "SSH public key contents. Overrides ssh_public_key_path when set (useful in CI)."
  type        = string
  default     = null
}

variable "extra_ssh_public_keys" {
  description = "Teammates' SSH public keys (contents, not paths), so they can log in too."
  type        = list(string)
  default     = []
}

variable "admin_cidrs" {
  description = "Public IPs allowed to SSH in, in CIDR form. Find yours with: curl ifconfig.me"
  type        = list(string)
}

variable "app_allowed_cidrs" {
  description = "Who can reach the API port. The API is public by default."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Port the API is published on. Must match the port Ansible publishes."
  type        = number
  default     = 3000

  validation {
    condition     = var.app_port > 1023 && var.app_port < 65536
    error_message = "app_port must be an unprivileged port (1024-65535)."
  }
}

variable "vnet_cidr" {
  description = "Address space of the virtual network."
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_cidr" {
  description = "Address range of the app subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 30
}

variable "extra_tags" {
  description = "Extra tags merged into the default ones."
  type        = map(string)
  default     = {}
}
