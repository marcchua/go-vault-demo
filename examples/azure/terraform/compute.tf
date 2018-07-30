data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

data "azurerm_image" "image" {
  name                = "${var.azure_image_name}"
  resource_group_name = "${var.azure_image_resource_group}"
}

resource "random_id" "tf" {
  byte_length = 4
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.azure_env}"
  location = "${var.azure_location}"

  tags {
    environment = "${var.azure_env}"
  }
}

resource "azurerm_virtual_network" "net" {
    name                = "${var.azure_env}-net"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.azure_location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    tags {
        environment = "${var.azure_env}"
    }
}

resource "azurerm_network_interface" "nic" {
    name                      = "${var.azure_env}-nic"
    location                  = "${var.azure_location}"
    resource_group_name       = "${azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.nsg.id}"

    ip_configuration {
        name                          = "${var.azure_env}-nic"
        subnet_id                     = "${azurerm_subnet.tf_subnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.pip.id}"
    }

    tags {
        environment = "${var.azure_env}"
    }
}

resource "azurerm_public_ip" "pip" {
    name                         = "${var.azure_env}-pip"
    location                     = "${var.azure_location}"
    resource_group_name          = "${azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "dynamic"

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

resource "azurerm_network_security_group" "nsg" {
    name                = "${var.azure_env}-nsg"
    location            = "${var.azure_location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    security_rule {
        name                       = "all"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "${var.azure_env}"
    }
}

resource "azurerm_virtual_machine" "vm" {
    name                  = "${var.azure_env}-vm"
    location              = "${var.azure_location}"
    resource_group_name   = "${azurerm_resource_group.rg.name}"
    network_interface_ids = ["${azurerm_network_interface.nic.id}"]
    vm_size               = "Standard_DS1_v2"

    identity = {
      type = "UserAssigned"
      identity_ids =  ["${data.azurerm_subscription.primary.id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${azurerm_user_assigned_identity.order.name}"]
    }

    storage_os_disk {
        name              = "${var.azure_env}-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    /*
    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }
    */

    storage_image_reference {
      id = "${data.azurerm_image.image.id}"
    }

    os_profile {
        computer_name  = "${var.azure_env}"
        admin_username = "azureuser"
        custom_data = <<SCRIPT
#!/bin/bash
cat << EOF > /app/config.toml
[database]
host="${var.postgres_host}"
port="${var.postgres_port}"
name="${var.postgres_database}"
mount="database"
role="order"
[vault]
host="${var.vault_host}"
mount="azure"
port="${var.vault_port}"
scheme="${var.vault_scheme}"
authentication="azure-msi"
role="order"
credential="https://${var.azure_env}-vault.com/"
EOF
systemctl enable go.service
service go restart
SCRIPT
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "${tls_private_key.go.public_key_openssh}"
        }
    }

    tags {
        environment = "${var.azure_env}"
    }

}
