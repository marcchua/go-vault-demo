output "go_ip" {
  value = "${kubernetes_service.go-frontend.load_balancer_ingress.0.ip}"
}

output "postgres_ip" {
  value = "${kubernetes_service.postgres-frontend.load_balancer_ingress.0.ip}"
}
