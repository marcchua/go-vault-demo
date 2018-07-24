output "vault_sa_key" {
 value = "${base64decode(google_service_account_key.vault.private_key)}"
}

output "go_sa_email" {
 value = "${google_service_account.go.email}"
}

output "order_sa_email" {
 value = "${google_service_account.order.email}"
}

output "gcp_project_id" {
  value = "${var.gcp_project_id}"
}

output "gcp_zone" {
  value = "${var.gcp_zone}"
}
