data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

data "azurerm_image" "image" {
  name                = "${var.azure_image_name}"
  resource_group_name = "${var.azure_image_resource_group}"
}

resource "azurerm_virtual_machine_scale_set" "go_ss" {
  name                = "${var.azure_env}-ss"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  upgrade_policy_mode = "Automatic"

  identity = {
    type = "UserAssigned"
    identity_ids =  ["${data.azurerm_subscription.primary.id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${azurerm_user_assigned_identity.order.name}"]
  }

  sku {
    name     = "Standard_F2"
    tier     = "Standard"
    capacity = "${var.azure_instances}"
  }

  storage_profile_image_reference {
    id = "${data.azurerm_image.image.id}"
  }

  storage_profile_os_disk {
  name              = ""
  caching           = "ReadWrite"
  create_option     = "FromImage"
  managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun            = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
      computer_name_prefix  = "go-"
      admin_username = "azure-user"
      admin_password = "${random_string.password.result}"
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
          path     = "/home/azure-user/.ssh/authorized_keys"
          key_data = "${tls_private_key.go.public_key_openssh}"
      }
  }

  network_profile {
    name    = "${var.azure_env}-net-profile"
    primary = true

    ip_configuration {
      name                                   = "PublicIPAddress"
      subnet_id                              = "${azurerm_subnet.tf_subnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.go.id}"]
    }
  }

  tags {
    environment = "${var.azure_env}"
  }
}

resource "azurerm_virtual_machine" "jumpbox" {
 name                  = "${var.azure_env}-jumpbox"
 location              = "${var.azure_location}"
 resource_group_name   = "${azurerm_resource_group.rg.name}"
 network_interface_ids = ["${azurerm_network_interface.jumpbox.id}"]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "${var.azure_env}-jumpbox-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "jumpbox"
   admin_username = "azure-user"
   admin_password = "${random_string.password.result}"
 }

 os_profile_linux_config {
     disable_password_authentication = true
     ssh_keys {
         path     = "/home/azure-user/.ssh/authorized_keys"
         key_data = "${tls_private_key.go.public_key_openssh}"
     }
 }

 tags {
   environment = "${var.azure_env}"
 }
}
