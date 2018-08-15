resource "kubernetes_service_account" "go" {
    metadata {
        name = "go"
    }
}

resource "kubernetes_service_account" "vault" {
    metadata {
        name = "vault"
    }
}
