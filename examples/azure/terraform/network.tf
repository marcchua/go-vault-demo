resource "azurerm_virtual_network" "net" {
    name                = "${var.azure_env}-net"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.azure_location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    tags {
        environment = "${var.azure_env}"
    }
}

resource "azurerm_subnet" "tf_subnet" {
    name                 = "${var.azure_env}-subnet"
    resource_group_name  = "${azurerm_resource_group.rg.name}"
    virtual_network_name = "${azurerm_virtual_network.net.name}"
    address_prefix       = "10.0.1.0/24"
}

resource "azurerm_public_ip" "lb_ip" {
  name                         = "${var.azure_env}-lb-pip"
  location                     = "${var.azure_location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${azurerm_resource_group.rg.name}"

  tags {
    environment = "${var.azure_env}"
  }
}

resource "azurerm_public_ip" "jumpbox_ip" {
 name                         = "${var.azure_env}-jump-ip"
 location                     = "${var.azure_location}"
 resource_group_name          = "${azurerm_resource_group.rg.name}"
 public_ip_address_allocation = "static"
 domain_name_label            = "${azurerm_resource_group.rg.name}-ssh"
 tags {
   environment = "${var.azure_env}"
 }
}

resource "azurerm_network_interface" "jumpbox" {
 name                = "${var.azure_env}-jump-nic"
 location            = "${var.azure_location}"
 resource_group_name = "${azurerm_resource_group.rg.name}"
 network_security_group_id     = "${azurerm_network_security_group.jumpbox.id}"

 ip_configuration {
   name                          = "PublicIPAddress"
   subnet_id                     = "${azurerm_subnet.tf_subnet.id}"
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = "${azurerm_public_ip.jumpbox_ip.id}"
 }

 tags {
   environment = "${var.azure_env}"
 }
}

resource "azurerm_network_security_group" "jumpbox" {
  name                = "${var.azure_env}-jump-sg"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags {
    environment = "${var.azure_env}"
  }
}
