terraform {
  backend "azurerm" {
    resource_group_name   = "rg-tfstate"
    storage_account_name  = "satfstate25726"
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.66.00"
    }
  }
}
provider "azurerm" {
  features {}
}

variable "resource_group"{
  type = string
}

variable "vnet1"{
  type = string
}

variable "subnet1"{
  type = string
}

variable "vm1_name"{
  type = string
}

variable "vm1_size"{
  type = string
}

variable "vm1_publisher"{
  type = string
}

variable "vm1_sku"{
  type = string
}

variable "vm1_offer"{
  type = string
}

variable "vm1_version"{
  type = string
}

variable "failover_location"{
  type = string
}

resource "random_integer" "ri" {
  min = 1000
  max = 9999
}
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
  name           = var.subnet1
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefix = "10.0.0.0/24"
}

resource "azurerm_network_interface" "nic-cc-dev" {
  name                = "nic-cc-dev"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm-cc-dev-1" {
  name                = var.vm1_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm1_size
  admin_username      = "adminuser"
  admin_password      = "letmeIN1@"
  disable_password_authentication = "false"
  network_interface_ids = [
    azurerm_network_interface.nic-cc-dev.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm1_publisher
    offer     = var.vm1_offer
    sku       = var.vm1_sku
    version   = var.vm1_version
  }
}

resource "azurerm_cosmosdb_account" "db" {
  name                = "tfex-cosmos-db-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  
  enable_automatic_failover = true

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 600
    max_staleness_prefix    = 200000
  }

  geo_location {
    location          = var.failover_location
    failover_priority = 0
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "db_keyvault"{
  name                       = "db-keyvault"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "create",
      "get",
    ]

    secret_permissions = [
      "set",
      "get",
      "delete",
      "purge",
      "recover"
    ]
  } 
}

resource "azurerm_key_vault_secret" "db_connection_strings"{
  name         = "db-connection-strings"
  value        = azurerm_cosmosdb_account.db.connection_strings
  key_vault_id = azurerm_key_vault.db_keyvault.id
}
