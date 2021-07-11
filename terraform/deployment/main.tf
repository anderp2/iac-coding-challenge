terraform {
  backend "azurerm" {
    resource_group_name   = "rg-tfstate"
    storage_account_name  = "satfstate25726"
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.00"
    }
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg-cc-dev" {
  name     = "rg-dev-cc"
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet-cc-dev" {
  name                = "vnet-cc-dev"
  location            = azurerm_resource_group.rg-cc-dev.location
  resource_group_name = azurerm_resource_group.rg-cc-dev.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet-cc-dev" {
  name           = "subnet-cc-dev"
  resource_group_name = azurerm_resource_group.rg-cc-dev.name
  virtual_network_name = azurerm_virtual_network.vnet-cc-dev.name
  address_prefix = "10.0.0.0/24"
}

resource "azurerm_network_interface" "nic-cc-dev" {
  name                = "nic-cc-dev"
  location            = azurerm_resource_group.rg-cc-dev.location
  resource_group_name = azurerm_resource_group.rg-cc-dev.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-cc-dev.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm-cc-dev-1" {
  name                = "vm-cc-dev-1"
  resource_group_name = azurerm_resource_group.rg-cc-dev.name
  location            = azurerm_resource_group.rg-cc-dev.location
  size                = "Standard_F2"
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
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.7"
    version   = "latest"
  }
}

