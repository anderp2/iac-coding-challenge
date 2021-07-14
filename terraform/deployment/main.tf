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

variable "db_type"{
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

resource "azurerm_cosmosdb_account" "db_account" {
  name                = "tfex-cosmos-db-account"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  is_virtual_network_filter_enabled = true
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
  
  virtual_network_rule  {
    id                = azurerm_subnet.subnet1.id
  } 
}

resource "azurerm_cosmosdb_mongo_database" "mongo_db" {
  count               = var.db_type == "mongo" ? 1 : 0
  name                = "tfex-cosmos-${var.db_type}-db"
  resource_group_name = azurerm_cosmosdb_account.db_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.db_account.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_database" "sql_db" {
  count               = var.db_type == "sql" ? 1 : 0
  name                = "tfex-cosmos-${var.db_type}-db"
  resource_group_name = azurerm_cosmosdb_account.db_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.db_account.name
  throughput          = 400
}

resource "azurerm_cosmosdb_gremlin_database" "gremlin_db" {
  count               = var.db_type == "gremlin" ? 1 : 0
  name                = "tfex-cosmos-${var.db_type}-db"
  resource_group_name = azurerm_cosmosdb_account.db_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.db_account.name
  throughput          = 400
}

