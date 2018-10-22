resource "kubernetes_pod" "postgres" {
  metadata {
    name = "postgres"
    labels {
      App = "postgres"
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
    }
  }
}

resource "kubernetes_service" "postgres-internal" {
    metadata {
        name = "postgres"
    }
    spec {
        selector {
            App = "${kubernetes_pod.postgres.metadata.0.labels.App}"
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
            App = "${kubernetes_pod.postgres.metadata.0.labels.App}"
        }
        port {
            port = 5432
            target_port = 5432
        }
        type = "LoadBalancer"
    }
}
