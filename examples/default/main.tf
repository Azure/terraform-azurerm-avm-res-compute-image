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

locals {
  # linux   = <<CUSTOM_DATA
  # #!/bin/bash
  # sudo waagent -deprovision+user
  # CUSTOM_DATA
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
