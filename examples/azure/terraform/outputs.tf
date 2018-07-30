output "order_principal_id" {
  value = "${azurerm_user_assigned_identity.order.principal_id}"
}

output "vault_tenant_id" {
  value = "${data.azurerm_client_config.current.tenant_id}"
}

output "vault_client_id" {
  value = "${azurerm_azuread_application.vault.application_id}"
}

output "vault_client_secret" {
  value = "VT=uSgbTanZhyz@%nL9Hpd+Tfay_MRV#"
}

output "vault_identifier_uri" {
  value = "https://${var.azure_env}-vault.com/"
}
