job "go" {
    datacenters = ["dc1"]
    type = "service"
    group "go" {
        constraint {
            operator = "distinct_hosts"
            value = "true"
        }
        count = 1
        task "go" {
            driver = "docker"
            config {
                image = "lanceplarsen/go-vault-demo"
                volumes = ["local/config.toml:/app/config.toml"]
		            network_mode = "host"
                port_map {
                    app = 3000
                }
            }
            template {
              data = <<EOH
              [database]
              host="{{ key "postgres/host" }}"
              port="5432"
              name="postgres"
              mount="database"
              role="order"
              [vault]
              host="active.vault.service.consul"
              port="8200"
              scheme="http"
              authentication="token"
              role="order"
              EOH
              destination = "local/config.toml"
            }
            resources {
                cpu = 500
                memory = 1024
                network {
                    mbits = 10
                    port "app" {
                        static = "3000"
                    }
                }
            }
            service {
                name = "go"
                tags = ["go", "urlprefix-/go strip=/go"]
                port = "app"
                check {
                    name = "alive"
                    type = "tcp"
                    interval = "10s"
                    timeout = "2s"
                }
            }
            vault {
              policies = ["order"]
            }
        }
    }
}
