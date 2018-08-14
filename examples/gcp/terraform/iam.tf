resource "random_id" "rand" {
  byte_length = 4
}

resource "google_service_account" "vault" {
  account_id   = "vault-${random_id.rand.hex}"
  display_name = "vault"
}

resource "google_service_account" "go" {
  account_id   = "go-${random_id.rand.hex}"
  display_name = "go"
}

resource "google_service_account" "order" {
  account_id   = "order-${random_id.rand.hex}"
  display_name = "order"
}

resource "google_service_account_key" "vault" {
  service_account_id = "${google_service_account.vault.name}"
  public_key_type = "TYPE_X509_PEM_FILE"
}

resource "google_service_account_iam_binding" "go" {
  service_account_id = "${google_service_account.order.name}"
  role        = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.go.email}",
  ]
}

resource "google_project_iam_member" "project" {
  project = "${var.gcp_project}"
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.vault.email}"
}
