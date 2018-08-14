provider azure {}

resource "random_id" "tf" {
  byte_length = 4
}

resource "random_string" "password" {
  length = 32
  special = true
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.azure_env}"
  location = "${var.azure_location}"

  tags {
    environment = "${var.azure_env}"
  }
}
