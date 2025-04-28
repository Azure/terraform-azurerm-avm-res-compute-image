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
  type = "Microsoft.Compute/virtualMachines@2024-11-01"
  body = {
    placement = {
      zonePlacementPolicy = "Any"
    }
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
            storageAccountType = "Standard_GZRS"
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
