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

### Declare variables
variable "resource_group"{
  type = string
}

variable "vnet1"{
  type = string
}

variable "subnet1"{
  type = string
}

variable "adminpassword"{
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

variable "capabilities"{
  type = string
  default = null
}

## Not used yet
locals {
  capabilities = var.db_type == "gremlin" ? null : "EnableGremlin"
}

resource "random_integer" "ri" {
  min = 1000
  max = 9999
}

### Azure Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnet1
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}

### Vnet Peering needed for ci-agent to ssh / configure Linux Virtual Machine
resource "azurerm_virtual_network_peering" "vnetpeer1" {
  name                      = "cc-to-ci"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = "/subscriptions/24249cfa-81f0-427c-932d-621edd58f968/resourceGroups/rg-ci/providers/Microsoft.Network/virtualNetworks/rg-ci-vnet"
}

resource "azurerm_virtual_network_peering" "vnetpeer2" {
  name                      = "ci-to-cc"
  resource_group_name       = "rg-ci"
  virtual_network_name      = "rg-ci-vnet"
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
}


### Azure subnet
resource "azurerm_subnet" "subnet1" {
  name           = var.subnet1
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefix = "10.1.0.0/24"
}

### Azure Network Interface
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

### Linux VM
resource "azurerm_linux_virtual_machine" "vm-cc-dev-1" {
  name                = var.vm1_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm1_size
  admin_username      = "adminuser"
  admin_password      = var.adminpassword
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
  connection {
    type        = "ssh"
    host        = azurerm_linux_virtual_machine.vm-cc-dev-1.private_ip_address
    user        = azurerm_linux_virtual_machine.vm-cc-dev-1.admin_username
    password    = azurerm_linux_virtual_machine.vm-cc-dev-1.admin_password
  }
  
  ### Add a user and group over ssh - could be abstracted to a shell script that we copy to the VM first then execute over ssh
  provisioner "remote-exec" {
    inline = [
      "sudo groupadd group1",
      "sudo useradd user1 -g group1",
    ]
  }
}


### Acure Cosmos DB Account (eastus and eastus2 are out of resources to deploy in those regions)
resource "azurerm_cosmosdb_account" "db_account" {
  name                = "tfex-cosmos-db-account-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = var.db_type == "mongo" ? "MongoDB" : "GlobalDocumentDB" 
  is_virtual_network_filter_enabled = true
  enable_automatic_failover = true

#### Future development to EnableGremlin capability in this resource  
#  dynamic capabilities { 
#    for_each = var.capabilities
#    content {
#      name = capabilities.value
#    }
#  }
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 600
    max_staleness_prefix    = 200000
  }

  geo_location {
    location          = "westus"
    failover_priority = 0
  }
  
  virtual_network_rule  {
    id                = azurerm_subnet.subnet1.id
    ignore_missing_vnet_service_endpoint = true
  } 
}


### Create a mongo_database resource if db_type == mongo
resource "azurerm_cosmosdb_mongo_database" "mongo_db" {
  count               = var.db_type == "mongo" ? 1 : 0
  name                = "tfex-cosmos-${var.db_type}-db"
  resource_group_name = azurerm_cosmosdb_account.db_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.db_account.name
  throughput          = 400
}

### Create a sql_database resource if db_type == sql
resource "azurerm_cosmosdb_sql_database" "sql_db" {
  count               = var.db_type == "sql" ? 1 : 0
  name                = "tfex-cosmos-${var.db_type}-db"
  resource_group_name = azurerm_cosmosdb_account.db_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.db_account.name
  throughput          = 400
}

### Create a gremlin_database resource if db_type == gremlin
resource "azurerm_cosmosdb_gremlin_database" "gremlin_db" {
  count               = var.db_type == "gremlin" ? 1 : 0
  name                = "tfex-cosmos-${var.db_type}-db"
  resource_group_name = azurerm_cosmosdb_account.db_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.db_account.name
  throughput          = 400
}

