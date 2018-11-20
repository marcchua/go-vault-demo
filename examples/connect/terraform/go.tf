resource "kubernetes_service_account" "go" {
    metadata {
        name = "go"
    }
}

resource "kubernetes_deployment" "go-frontend" {
metadata {
  name = "go-frontend"
  labels {
    App = "go-frontend"
  }
}

  spec {
    replicas = "${var.k8s_instances}"

    selector {
      match_labels {
        App = "go-frontend"
      }
    }

    template {
    metadata {
      name = "go-frontend"
      labels {
        App = "go-frontend"
      }
      annotations {
        "consul.hashicorp.com/connect-inject" = "true"
        "consul.hashicorp.com/connect-service-upstreams" = "postgres:5432"
      }
    }

      spec {
        service_account_name = "go"
        container {
            image = "${var.go_docker_container}"
            image_pull_policy = "Always"
            name = "go"
            volume_mount {
                mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
                name = "${kubernetes_service_account.go.default_secret_name}"
            }
            volume_mount {
                mount_path = "/app/config.toml"
                sub_path = "config.toml"
                name = "${kubernetes_config_map.go.metadata.0.name}"
            }
            port {
                container_port = 8080
            }
        }
        volume {
            name = "${kubernetes_service_account.go.default_secret_name}"
            secret {
                secret_name = "${kubernetes_service_account.go.default_secret_name}"
            }
        }
        volume {
            name = "${kubernetes_config_map.go.metadata.0.name}"
            config_map {
                name = "go"
                items {
                    key = "config"
                    path =  "config.toml"
                }
            }
        }

      }
    }
  }
}

resource "kubernetes_service" "go-internal" {
    metadata {
        name = "go"
    }
    spec {
        selector {
            App = "${kubernetes_deployment.go-frontend.metadata.0.labels.App}"
        }
        port {
            port = 8080
            target_port = 8080
        }
        type = "ClusterIP"
    }
}

resource "kubernetes_service" "go-frontend" {
    metadata {
        name = "go-frontend"
    }
    spec {
        selector {
            App = "${kubernetes_deployment.go-frontend.metadata.0.labels.App}"
        }
        port {
            port = 8080
            target_port = 8080
        }
        type = "LoadBalancer"
    }
}

resource "kubernetes_config_map" "go" {
  metadata {
    name = "go"
  }
  data {
    config = <<EOF
[server]
port="8080"
[database]
host="${var.postgres_host}"
port="${var.postgres_port}"
name="${var.postgres_instance}"
[vault]
host="${var.vault_host}"
port="${var.vault_port}"
scheme="${var.vault_scheme}"
authentication="kubernetes"
mount="kubernetes"
role="order"
[vault.credential]
serviceaccount="/var/run/secrets/kubernetes.io/serviceaccount/token"
[vault.database]
mount="database"
role="order"
[vault.transit]
key="order"
mount="transit"
EOF
  }
}
