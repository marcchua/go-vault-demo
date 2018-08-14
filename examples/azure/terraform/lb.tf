resource "azurerm_lb" "go" {
  name                = "${var.azure_env}-lb"
  location            = "${var.azure_location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.lb_ip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "go" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.go.id}"
  name                = "${var.azure_env}-backend-pool"
}

resource "azurerm_lb_probe" "go" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.go.id}"
  name                = "${var.azure_env}-probe"
  port                = 3000
  protocol            = "HTTP"
  request_path        = "/health"
}

resource "azurerm_lb_rule" "go" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.go.id}"
  name                           = "Go"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 3000
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.go.id}"
  probe_id                       = "${azurerm_lb_probe.go.id}"
}
