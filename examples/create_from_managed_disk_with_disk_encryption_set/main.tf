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

data "azurerm_client_config" "current" {}

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

resource "azurerm_key_vault" "this" {
  location                    = azurerm_resource_group.this.location
  name                        = module.naming.key_vault.name_unique
  resource_group_name         = azurerm_resource_group.this.name
  sku_name                    = "premium"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
}

resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.this.id
  object_id    = data.azurerm_client_config.current.object_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "Purge",
    "Recover",
    "Update",
    "List",
    "Decrypt",
    "Sign",
    "GetRotationPolicy",
    "UnwrapKey",
    "WrapKey",
  ]
}

resource "azurerm_key_vault_key" "this" {
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
  key_type     = "RSA"
  key_vault_id = azurerm_key_vault.this.id
  name         = module.naming.key_vault_key.name
  key_size     = 2048

  depends_on = [
    azurerm_key_vault_access_policy.current
  ]
}

resource "azurerm_disk_encryption_set" "this" {
  location                  = azurerm_resource_group.this.location
  name                      = module.naming.disk_encryption_set.name_unique
  resource_group_name       = azurerm_resource_group.this.name
  auto_key_rotation_enabled = true
  key_vault_key_id          = azurerm_key_vault_key.this.versionless_id

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "this" {
  key_vault_id = azurerm_key_vault.this.id
  object_id    = azurerm_disk_encryption_set.this.identity[0].principal_id
  tenant_id    = azurerm_disk_encryption_set.this.identity[0].tenant_id
  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "Purge",
    "Recover",
    "Update",
    "List",
    "Decrypt",
    "Sign",
    "WrapKey",
    "UnwrapKey",
  ]
}

resource "azurerm_role_assignment" "this" {
  principal_id         = azurerm_disk_encryption_set.this.identity[0].principal_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
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
            diskEncryptionSet = {
              id = azurerm_disk_encryption_set.this.id
            }
          }
        }
        dataDisks = [
          {
            name         = module.naming.managed_disk.name_unique
            caching      = "ReadWrite"
            lun          = 0
            createOption = "Empty"
            diskSizeGB   = 30
            managedDisk = {
              storageAccountType = "Premium_ZRS"
            }
          }
        ]
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
    id                = "${azurerm_resource_group.this.id}/providers/Microsoft.Compute/disks/${azapi_resource.linux.body.properties.storageProfile.osDisk.name}"
    caching           = azapi_resource.linux.body.properties.storageProfile.osDisk.caching
    size_gb           = azapi_resource.linux.body.properties.storageProfile.osDisk.diskSizeGB
    os_type           = "Linux"
    encryption_set_id = azurerm_disk_encryption_set.this.id
  }

  data_disks = [
    {
      id           = "${azurerm_resource_group.this.id}/providers/Microsoft.Compute/disks/${azapi_resource.linux.body.properties.storageProfile.dataDisks[0].name}"
      caching      = azapi_resource.linux.body.properties.storageProfile.dataDisks[0].caching
      size_gb      = azapi_resource.linux.body.properties.storageProfile.dataDisks[0].diskSizeGB
      storage_type = azapi_resource.linux.body.properties.storageProfile.dataDisks[0].managedDisk.storageAccountType
      lun          = azapi_resource.linux.body.properties.storageProfile.dataDisks[0].lun
    }
  ]

  depends_on = [azapi_resource.linux]
}
