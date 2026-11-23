output "public_ip" {
  description = "Public IP of the load balancer."
  value       = azurerm_public_ip.this.ip_address
}

output "fqdn" {
  description = "DNS name of the load balancer."
  value       = azurerm_public_ip.this.fqdn
}

output "lb_id" {
  description = "ID of the load balancer."
  value       = azurerm_lb.this.id
}
