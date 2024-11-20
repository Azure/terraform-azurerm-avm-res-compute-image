<!-- BEGIN_TF_DOCS -->
# Create a virtual machine image from a managed disk

This example shows how to generate a VM image using a managed disk as the source without additional encryption resources.

```hcl
terraform {
  required_version = "~> 1.9"
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.00, < 3"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "< 4.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "random_password" "this" {
  length           = 16
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  min_upper        = 2
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
  special          = true
}

resource "random_string" "this" {
  length  = 16
  special = false
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = "~> 0.3"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "this" {
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = module.naming.subnet.name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_network_interface" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.network_interface.name
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "primary"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.this.id
  }
}

resource "azapi_resource" "linux" {
  type = "Microsoft.Compute/virtualMachines@2024-07-01"
  body = {
    properties = {
      hardwareProfile = {
        vmSize = "Standard_D2s_v3"
      }
      storageProfile = {
        imageReference = {
          publisher = "debian"
          offer     = "debian-12"
          sku       = "12"
          version   = "latest"
        }
        osDisk = {
          name         = module.naming.managed_disk.name
          caching      = "ReadWrite"
          createOption = "FromImage"
          diskSizeGB   = 30
          managedDisk = {
            storageAccountType = "Premium_ZRS"
          }
        }
      }
      osProfile = {
        computerName  = "lin-${module.naming.windows_virtual_machine.name}"
        adminUsername = random_string.this.result
        adminPassword = random_password.this.result
        linuxConfiguration = {
          disablePasswordAuthentication = false
        }
      }
      networkProfile = {
        networkInterfaces = [
          {
            id = azurerm_network_interface.this.id
            properties = {
              deleteOption = "Delete"
              primary      = true
            }
          }
        ]
      }
    }
  }
  location  = azurerm_resource_group.this.location
  name      = "lin-${module.naming.windows_virtual_machine.name}"
  parent_id = azurerm_resource_group.this.id

  lifecycle {
    ignore_changes = all
  }
}

module "image" {
  source              = "../../"
  location            = azurerm_resource_group.this.location
  name                = module.naming.image.name
  resource_group_name = azurerm_resource_group.this.name
  hyperv_generation   = "V1"
  enable_telemetry    = true

  os_disk = {
    id      = "${azurerm_resource_group.this.id}/providers/Microsoft.Compute/disks/${azapi_resource.linux.body.properties.storageProfile.osDisk.name}"
    caching = azapi_resource.linux.body.properties.storageProfile.osDisk.caching
    size_gb = azapi_resource.linux.body.properties.storageProfile.osDisk.diskSizeGB
    os_type = "Linux"
  }

  depends_on = [azapi_resource.linux]
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.9)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (>= 2.00, < 3)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (< 4.9.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5)

## Resources

The following resources are used by this module:

- [azapi_resource.linux](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource) (resource)
- [azurerm_network_interface.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)
- [random_password.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) (resource)
- [random_string.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

No outputs.

## Modules

The following Modules are called:

### <a name="module_image"></a> [image](#module\_image)

Source: ../../

Version:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: ~> 0.3

### <a name="module_regions"></a> [regions](#module\_regions)

Source: Azure/regions/azurerm

Version: ~> 0.3

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->