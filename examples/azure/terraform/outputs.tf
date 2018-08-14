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
  value = "${random_string.password.result}"
}

output "vault_identifier_uri" {
  value = "https://${var.azure_env}-vault.com/"
}

output "go-app-dns" {
  value = "${azurerm_public_ip.lb_ip.fqdn}"
}

output "go-jumpbox-dns" {
  value = "${azurerm_public_ip.jumpbox_ip.fqdn}"
}
