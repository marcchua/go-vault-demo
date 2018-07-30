resource "azurerm_azuread_application" "vault"  {
  name = "${var.azure_env}-vault"
  identifier_uris = ["https://${var.azure_env}-vault.com/"]
}

resource "azurerm_azuread_service_principal" "vault" {
  application_id = "${azurerm_azuread_application.vault.application_id}"
}

resource "azurerm_role_assignment" "vault" {
  scope                = "${data.azurerm_subscription.primary.id}"
  role_definition_name = "Reader"
  principal_id         = "${azurerm_azuread_service_principal.vault.id}"
}

resource "azurerm_azuread_service_principal_password" "vault" {
  service_principal_id = "${azurerm_azuread_service_principal.vault.id}"
  value                = "VT=uSgbTanZhyz@%nL9Hpd+Tfay_MRV#"
  end_date             = "2019-01-01T00:00:00Z"
}

resource "azurerm_user_assigned_identity" "order" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${var.azure_location}"

  name = "${var.azure_env}-order"
}
