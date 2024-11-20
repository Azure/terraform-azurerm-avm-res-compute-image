<!-- BEGIN_TF_DOCS -->
# Create a virtual machine image from an existing virtual machine

This example demonstrates how to prepare both Windows and Linux virtual machines as base configurations for creating a managed image. The process involves deprovisioning or generalizing the VM to remove any machine-specific data, ensuring the virtual machine is in a clean, reusable state before capturing it as an image.

For the Linux VM, the Azure VM Agent (waagent) is used to deprovision the machine, removing all machine-specific files and sensitive data to ensure it is generalized for use as a base image. The Windows VM undergoes a similar process, with Sysprep being run to remove all personal accounts, security settings, and unique identifiers, followed by deallocation and generalization.

Both VMs will be deallocated and generalized to create a clean image that can be used to provision additional VMs. After generalizing, the VMs will serve as the source for generating a managed image in Azure.

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
      version = ">= 3.116.0"
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

## Custom Initialization Scripts
# The Azure VM Agent (waagent) is utilized to deprovision the Linux virtual machine and remove machine-specific files and sensitive data
# Sysprep is executed to remove all personal accounts, security settings, and unique identifiers from the Windows virtual machine
locals {
  linux   = <<CUSTOM_DATA
  #!/bin/bash
  sudo waagent -deprovision+user
  CUSTOM_DATA
  windows = <<CUSTOM_DATA
  cd $env:windir\\system32\\sysprep; rm -r -fo Panther; .\\sysprep.exe /generalize /shutdown /oobe
  CUSTOM_DATA
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
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_network_interface" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.network_interface.name_unique
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "primary"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.this.id
  }
}

# Windows
resource "azurerm_windows_virtual_machine" "this" {
  admin_password = random_password.this.result
  admin_username = random_string.this.result
  location       = azurerm_resource_group.this.location
  name           = "win-${module.naming.windows_virtual_machine.name_unique}"
  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]
  resource_group_name = azurerm_resource_group.this.name
  size                = "Standard_D4s_v3"
  custom_data         = base64encode(local.windows)

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_ZRS"
    name                 = module.naming.managed_disk.name_unique
  }
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "azapi_resource_action" "deallocate" {
  resource_id = azurerm_windows_virtual_machine.this.id
  type        = "Microsoft.Compute/virtualMachines@2024-07-01"
  action      = "Deallocate"
}

resource "azapi_resource_action" "generalize" {
  resource_id = azurerm_windows_virtual_machine.this.id
  type        = "Microsoft.Compute/virtualMachines@2024-07-01"
  action      = "Generalize"

  depends_on = [azapi_resource_action.deallocate]
}

# Linux
# resource "azurerm_linux_virtual_machine" "this" {
#   name                            = "lin-${module.naming.windows_virtual_machine.name_unique}"
#   resource_group_name             = azurerm_resource_group.this.name
#   location                        = azurerm_resource_group.this.location
#   size                            = "Standard_D2s_v3"
#   custom_data                     = base64encode(local.linux)
#   admin_username                  = random_string.this.result
#   admin_password                  = random_password.this.result
#   disable_password_authentication = false
#   network_interface_ids = [
#     azurerm_network_interface.this.id,
#   ]

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts"
#     version   = "latest"
#   }

#   os_disk {
#     name                 = module.naming.managed_disk.name_unique
#     storage_account_type = "Standard_LRS"
#     caching              = "ReadWrite"
#   }

#   lifecycle {
#    ignore_changes = all
#  }
# }

# This resource deallocates (stops and releases) the Linux virtual machine to prepare it for generalization
# resource "azapi_resource_action" "deallocate" {
#   type        = "Microsoft.Compute/virtualMachines@2024-07-01"
#   resource_id = azurerm_linux_virtual_machine.this.id
#   action      = "Deallocate"
# }

# This resource marks the Linuxvirtual machine as generalized
# resource "azapi_resource_action" "generalize" {
#   type        = "Microsoft.Compute/virtualMachines@2024-07-01"
#   resource_id = azurerm_linux_virtual_machine.this.id
#   action      = "Generalize"

#   depends_on = [azapi_resource_action.deallocate]
# }

module "image" {
  source                    = "../../"
  location                  = azurerm_resource_group.this.location
  name                      = module.naming.image.name_unique
  resource_group_name       = azurerm_resource_group.this.name
  hyperv_generation         = "V1"
  source_virtual_machine_id = azurerm_windows_virtual_machine.this.id
  enable_telemetry          = true

  depends_on = [azapi_resource_action.generalize]
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.9)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (>= 2.00, < 3)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.116.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5)

## Resources

The following resources are used by this module:

- [azapi_resource_action.deallocate](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource_action) (resource)
- [azapi_resource_action.generalize](https://registry.terraform.io/providers/azure/azapi/latest/docs/resources/resource_action) (resource)
- [azurerm_network_interface.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [azurerm_windows_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine) (resource)
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