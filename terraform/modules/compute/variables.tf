variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the VM."
  type        = string
}

variable "subnet_id" {
  description = "Subnet the VM's network card joins."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
}

variable "admin_username" {
  description = "Login user created on the VM. Ansible connects as this user."
  type        = string
}

variable "ssh_public_key" {
  description = "Contents of the SSH public key allowed to log in (RSA; Azure rejects some other types)."
  type        = string

  validation {
    condition     = startswith(trimspace(var.ssh_public_key), "ssh-rsa ")
    error_message = "ssh_public_key must be an OpenSSH RSA public key (starts with ssh-rsa)."
  }
}

variable "os_disk_type" {
  description = "Managed disk type for the OS disk."
  type        = string
  default     = "Standard_LRS"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
}
