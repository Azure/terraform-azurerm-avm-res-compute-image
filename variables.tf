variable "hyperv_generation" {
  type        = string
  description = "Specifies which generation of Hyper-V the image should be compatible with: 'V1' or 'V2'."
  nullable    = false

  validation {
    condition     = contains(["V1", "V2"], var.hyperv_generation)
    error_message = "The generation must be either 'V1' or 'V2'."
  }
}

variable "location" {
  type        = string
  description = "The Azure location where the image should exist."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the image."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,80}$", var.name))
    error_message = "The name must be between 1 and 80 characters long and can only contain letters, numbers, underscores, periods, and dashes."
  }
  validation {
    error_message = "The name must start with a letter or a number"
    condition     = can(regex("^[a-zA-Z0-9]", var.name))
  }
  validation {
    error_message = "The name must end with a letter or a number or an undescore"
    condition     = can(regex("[a-zA-Z0-9_]$", var.name))
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the image."
  nullable    = false
}

variable "data_disks" {
  type = list(object({
    storage_type      = string
    lun               = number
    blob_uri          = optional(string, null)
    caching           = optional(string, null)
    size_gb           = optional(number, null)
    encryption_set_id = optional(string, null)
    snapshot_id       = optional(string, null)
    id                = optional(string, null)
  }))
  default     = null
  description = "(Optional) A list of data disks for the image. Each object represents a disk configuration."

  validation {
    condition = var.data_disks == null || alltrue([
      for disk in(var.data_disks != null ? var.data_disks : []) : (
        disk.blob_uri != null || disk.snapshot_id != null || disk.id != null
      )
    ])
    error_message = "At least one of 'blob_uri', 'snapshot_id', or 'id' must be set if 'data_disks' is provided."
  }
  validation {
    condition = var.data_disks == null || alltrue([
      for disk in(var.data_disks != null ? var.data_disks : []) : (
        disk.caching == null || contains(["ReadOnly", "None", "ReadWrite"], disk.caching)
      )
    ])
    error_message = "The caching must be one of 'ReadOnly', 'None', or 'ReadWrite' if provided."
  }
  validation {
    condition = var.data_disks == null || alltrue([
      for disk in(var.data_disks != null ? var.data_disks : []) : (
        contains(["PremiumV2_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_LRS", "StandardSSD_ZRS", "Standard_LRS", "UltraSSD_LRS"], disk.storage_type)
      )
    ])
    error_message = "The storage account type must be one of 'PremiumV2_LRS', 'Premium_LRS', 'Premium_ZRS', 'StandardSSD_LRS', 'StandardSSD_ZRS', 'Standard_LRS', or 'UltraSSD_LRS'."
  }
  validation {
    condition = var.data_disks == null || alltrue([
      for disk in(var.data_disks != null ? var.data_disks : []) : (
        disk.size_gb == null || disk.size_gb <= 1023
      )
    ])
    error_message = "The disk size must not be greater than 1023 GB."
  }
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "os_disk" {
  type = object({
    os_type           = string
    os_state          = optional(string, "Generalized")
    storage_type      = optional(string, "Premium_ZRS")
    blob_uri          = optional(string, null)
    caching           = optional(string, "None")
    size_gb           = optional(number, 127)
    snapshot_id       = optional(string, null)
    encryption_set_id = optional(string, null)
    id                = optional(string, null)
  })
  default     = null
  description = "(Optional) A map of os disk for the image. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time."

  validation {
    condition = (
      var.os_disk != null ?
      (
        var.os_disk.blob_uri != null ||
        var.os_disk.snapshot_id != null ||
        var.os_disk.id != null
      ) : true
    )
    error_message = "At least one of 'blob_uri', 'snapshot_id', or 'id' must be set if 'os_disk' is provided."
  }
  validation {
    condition = (
      var.os_disk != null ?
      contains(["ReadOnly", "None", "ReadWrite"], var.os_disk.caching) : true
    )
    error_message = "The caching must be one of 'ReadOnly', 'None', or 'ReadWrite' if provided."
  }
  validation {
    condition = (
      var.os_disk != null ?
      contains(["PremiumV2_LRS", "Premium_LRS", "Premium_ZRS", "StandardSSD_LRS", "StandardSSD_ZRS", "Standard_LRS"], var.os_disk.storage_type) : true
    )
    error_message = "The storage type must be one of 'PremiumV2_LRS', 'Premium_LRS', 'Premium_ZRS', 'StandardSSD_LRS', 'StandardSSD_ZRS', or 'Standard_LRS'."
  }
  validation {
    condition = (
      var.os_disk != null ?
      contains(["Specialized", "Generalized"], var.os_disk.os_state) : true
    )
    error_message = "The state must be either 'Specialized' or 'Generalized'."
  }
  validation {
    condition = (
      var.os_disk != null ?
      var.os_disk.size_gb <= 1023 : true
    )
    error_message = "The disk size must not be greater than 1023 GB."
  }
  validation {
    condition = (
      var.os_disk != null ?
      contains(["Windows", "Linux"], var.os_disk.os_type) : true
    )
    error_message = " The type of the OS that is included in the disk if creating a VM from a custom image must be 'Windows' or 'Linux'."
  }
}

variable "source_virtual_machine_id" {
  type        = string
  default     = null
  description = "(Optional) The Id of the source virtual machine from which the image is created."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Map of tags to assign to the image."
}

variable "zone_resilient" {
  type        = bool
  default     = true
  description = "Specifies whether the image is zone resilient or not. Zone resilient images can be created only in regions that provide Zone Redundant Storage (ZRS)."
  nullable    = false
}
