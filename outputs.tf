output "name" {
  description = "The resource name of the image."
  value       = azurerm_image.this.name
}

output "resource" {
  description = "The image."
  value       = azurerm_image.this
}

output "resource_id" {
  description = "The resource ID of the image."
  value       = azurerm_image.this.id
}
