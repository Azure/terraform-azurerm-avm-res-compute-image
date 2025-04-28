<!-- BEGIN_TF_DOCS -->
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

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.9)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 4.0)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (0.3.2)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5)

## Resources

The following resources are used by this module:

- [azurerm_image.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/image) (resource)
- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [modtm_telemetry.telemetry](https://registry.terraform.io/providers/Azure/modtm/0.3.2/docs/resources/telemetry) (resource)
- [random_uuid.telemetry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) (resource)
- [azurerm_client_config.telemetry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [modtm_module_source.telemetry](https://registry.terraform.io/providers/Azure/modtm/0.3.2/docs/data-sources/module_source) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_hyperv_generation"></a> [hyperv\_generation](#input\_hyperv\_generation)

Description: Specifies which generation of Hyper-V the image should be compatible with: 'V1' or 'V2'.

Type: `string`

### <a name="input_location"></a> [location](#input\_location)

Description: The Azure location where the image should exist.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: The name of the image.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: The name of the resource group in which to create the image.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_data_disks"></a> [data\_disks](#input\_data\_disks)

Description: (Optional) A list of data disks for the image. Each object represents a disk configuration.

Type:

```hcl
list(object({
    storage_type      = string
    lun               = number
    blob_uri          = optional(string, null)
    caching           = optional(string, null)
    size_gb           = optional(number, null)
    encryption_set_id = optional(string, null)
    snapshot_id       = optional(string, null)
    id                = optional(string, null)
  }))
```

Default: `null`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see https://aka.ms/avm/telemetryinfo.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_lock"></a> [lock](#input\_lock)

Description: Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.

Type:

```hcl
object({
    kind = string
    name = optional(string, null)
  })
```

Default: `null`

### <a name="input_os_disk"></a> [os\_disk](#input\_os\_disk)

Description: (Optional) A map of os disk for the image. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

Type:

```hcl
object({
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
```

Default: `null`

### <a name="input_source_virtual_machine_id"></a> [source\_virtual\_machine\_id](#input\_source\_virtual\_machine\_id)

Description: (Optional) The Id of the source virtual machine from which the image is created.

Type: `string`

Default: `null`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: Map of tags to assign to the image.

Type: `map(string)`

Default: `null`

### <a name="input_zone_resilient"></a> [zone\_resilient](#input\_zone\_resilient)

Description: Specifies whether the image is zone resilient or not. Zone resilient images can be created only in regions that provide Zone Redundant Storage (ZRS).

Type: `bool`

Default: `true`

## Outputs

The following outputs are exported:

### <a name="output_name"></a> [name](#output\_name)

Description: The resource name of the image.

### <a name="output_resource"></a> [resource](#output\_resource)

Description: The image.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The resource ID of the image.

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->