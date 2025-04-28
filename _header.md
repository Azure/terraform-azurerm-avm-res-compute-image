# Azure Image Module

This module is used to create and manage managed images, excluding gallery images versions and definitions.

## Features

The module includes the following functionalities:

- Creating a virtual machine image from a blob.
- Creating a virtual machine image from a managed disk with DiskEncryptionSet resource.
- Creating a virtual machine image from a managed disk.
- Creating a virtual machine image from an existing virtual machine.
- Creating a virtual machine image that includes a data disk from a blob.
- Creating a virtual machine image that includes a data disk from a managed disk.

## Usage

To use this module in your Terraform configuration, you'll need to provide values for the required variables.

### Example - Create a managed image from a blob

This example demonstrates how to create an image from a VHD or blob.

```terraform
module "avm-res-compute-image" {
  source = "Azure/avm-res-compute-image/azurerm"

  resource_group_name = "myResourceGroup"
  location            = "East US"
  image_name          = "myImage"
  hyperv_generation   = "V1"
  enable_telemetry    = true

  os_disk = {
    blob_uri     = "https://myblobstorage.blob.core.windows.net/vhds/my-vhd.vhd"
    caching      = "None"
    size_gb      = 30
    storage_type = "Standard_LRS"
    os_type      = "Linux"
  }
}
```

### Example - Create a managed image from a virtual machine

This example demonstrates how to create an image from a virtual machine.

```terraform
module "avm-res-compute-image" {
  source = "Azure/avm-res-compute-image/azurerm"

  resource_group_name       = "myResourceGroup"
  location                  = "East US"
  image_name                = "myImage"
  hyperv_generation         = "V1"
  enable_telemetry          = true
  source_virtual_machine_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.Compute/virtualMachines/myVM"
}
```

### Example - Create a managed image from a managed disk

This example demonstrates how to create an image from a managed disk.

```terraform
module "avm-res-compute-image" {
  source = "Azure/avm-res-compute-image/azurerm"

  resource_group_name = "myResourceGroup"
  location            = "East US"
  image_name          = "myImage"
  hyperv_generation   = "V1"
  enable_telemetry    = true

  os_disk = {
    id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.Compute/disks/myDisk"
    caching = "None"
    size_gb = 30
    os_type = "Linux"
  }
}
```
