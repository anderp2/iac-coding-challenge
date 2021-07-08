provider "azurerm" {
  version = "=1.44.0"
}

resource "azurerm_resource_group" "rg-cc-dev" {
  name     = "rg-dev-cc"
  location = "useast"
}

