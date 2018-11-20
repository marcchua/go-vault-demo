resource "kubernetes_deployment" "postgres" {
  metadata {
    name = "postgres"
    labels {
      app = "postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels {
          app = "postgres"
        }
        annotations {
          "consul.hashicorp.com/connect-inject" = "true"
        }
      }

      spec {
        container {
          image = "launcher.gcr.io/google/postgresql9"
          name  = "postgres"
          env {
            name = "POSTGRES_PASSWORD"
            value = "postgres"
          }
          port {
            container_port = 5432
            name = "tcp"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres-internal" {
    metadata {
        name = "postgres"
    }
    spec {
        selector {
            app = "${kubernetes_deployment.postgres.metadata.0.labels.app}"
        }
        port {
            port = 5432
            target_port = 5432
        }
        type = "ClusterIP"
    }
}

resource "kubernetes_service" "postgres-frontend" {
    metadata {
        name = "postgres-frontend"
    }
    spec {
        selector {
            app = "${kubernetes_deployment.postgres.metadata.0.labels.app}"
        }
        port {
            port = 5432
            target_port = 5432
        }
        type = "LoadBalancer"
    }
}
