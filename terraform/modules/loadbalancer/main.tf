# Public entry point for the API. The app VM has no public IP; users reach it
# through this Standard load balancer:
#
#   http://<dns_label>.<region>.cloudapp.azure.com  :80
#        -> backend pool (app VM NIC)                :app_port
#
# The health probe calls the API's health path every few seconds. A VM that stops
# answering 200 is taken out of rotation - the same signal operators watch.
#
# The outbound rule gives the private VM a way out to the internet (apt, ACR) through
# the load balancer's IP, since it has no public IP of its own.

resource "azurerm_public_ip" "this" {
  name                = "${var.name_prefix}-lb-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.dns_label
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = "${var.name_prefix}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_lb_backend_address_pool" "app" {
  name            = "app"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_network_interface_backend_address_pool_association" "app" {
  for_each = var.backend_nics

  network_interface_id    = each.value.nic_id
  ip_configuration_name   = each.value.ip_configuration_name
  backend_address_pool_id = azurerm_lb_backend_address_pool.app.id
}

resource "azurerm_lb_probe" "health" {
  name                = "api-health"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = "Http"
  port                = var.backend_port
  request_path        = var.health_path
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = var.frontend_port
  backend_port                   = var.backend_port
  frontend_ip_configuration_name = "public"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.app.id]
  probe_id                       = azurerm_lb_probe.health.id
  idle_timeout_in_minutes        = 4

  # Outbound traffic is handled by the explicit outbound rule below.
  disable_outbound_snat = true
}

resource "azurerm_lb_outbound_rule" "egress" {
  name                     = "egress"
  loadbalancer_id          = azurerm_lb.this.id
  protocol                 = "All"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.app.id
  allocated_outbound_ports = 1024

  frontend_ip_configuration {
    name = "public"
  }
}
