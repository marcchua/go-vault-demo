resource "kubernetes_service_account" "go" {
    metadata {
        name = "go"
    }
}
