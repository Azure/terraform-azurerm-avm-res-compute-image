resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_image.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_image" "this" {
  location                  = var.location
  name                      = var.name
  resource_group_name       = var.resource_group_name
  hyper_v_generation        = var.hyperv_generation
  source_virtual_machine_id = var.source_virtual_machine_id
  tags                      = var.tags
  zone_resilient            = var.zone_resilient

  dynamic "data_disk" {
    for_each = var.data_disks != null ? var.data_disks : []

    content {
      storage_type           = data_disk.value.storage_type
      blob_uri               = data_disk.value.blob_uri
      caching                = data_disk.value.caching
      disk_encryption_set_id = data_disk.value.encryption_set_id
      lun                    = data_disk.value.lun
      managed_disk_id        = data_disk.value.id
      size_gb                = data_disk.value.size_gb
    }
  }
  dynamic "os_disk" {
    for_each = var.os_disk != null ? [var.os_disk] : []

    content {
      storage_type           = var.os_disk.storage_type
      blob_uri               = var.os_disk.blob_uri
      caching                = var.os_disk.caching
      disk_encryption_set_id = var.os_disk.encryption_set_id
      managed_disk_id        = var.os_disk.id
      os_state               = var.os_disk.os_state
      os_type                = var.os_disk.os_type
      size_gb                = var.os_disk.size_gb
    }
  }
}
