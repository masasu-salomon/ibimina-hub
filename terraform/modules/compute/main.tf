# One Ubuntu VM. Used twice by envs/dev:
#   - the bastion: public subnet, its own static public IP, no identity
#   - the app VM:  private subnet, no public IP, a managed identity that may pull
#                  from the container registry
# Nothing is installed here: Terraform stops at "a reachable, empty Linux box";
# Ansible hardens it, installs Docker and deploys the app.

resource "azurerm_public_ip" "this" {
  count = var.public_ip_enabled ? 1 : 0

  name                = "${var.name_prefix}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Static so the address survives a reboot and the Ansible inventory stays valid.
  allocation_method = "Static"
  sku               = "Standard"
  tags              = var.tags
}

resource "azurerm_network_interface" "this" {
  #checkov:skip=CKV_AZURE_119:Only the bastion gets a public IP (public_ip_enabled); SSH to it is limited to admin /32s by its NSG. The app VM has none.
  name                = "${var.name_prefix}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_enabled ? azurerm_public_ip.this[0].id : null
  }
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.name_prefix}-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.this.id]

  # Key-only login. Ansible's hardening role also turns password login off in sshd.
  admin_username                  = var.admin_username
  disable_password_authentication = true

  # One block per key (operator, teammates, CD deploy key), all for the same user.
  dynamic "admin_ssh_key" {
    for_each = var.ssh_public_keys
    content {
      username   = var.admin_username
      public_key = admin_ssh_key.value
    }
  }

  # A system-assigned managed identity lets the VM get Azure tokens from the
  # metadata endpoint, e.g. to pull images from ACR, without any stored password.
  dynamic "identity" {
    for_each = var.identity_enabled ? [1] : []
    content {
      type = "SystemAssigned"
    }
  }

  # No VM extensions: everything on the box is managed by Ansible, so there is
  # one source of truth and no agent-installed software we did not review.
  allow_extension_operations = false

  os_disk {
    name                 = "${var.name_prefix}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Boot diagnostics in a Microsoft-managed storage account: the serial console
  # works if a bad sshd or firewall change locks us out.
  boot_diagnostics {}
}
