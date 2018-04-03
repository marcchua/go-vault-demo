job "go" {
    region = "us"
    datacenters = ["us-east-1"]
    type = "service"
    group "go" {
        constraint {
            operator = "distinct_hosts"
            value = "true"
        }
        count = 3
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
              [vault]
              server="http://52.90.84.48:8200"
              [database]
              server="llarsenvaultdb.cihgglcplvpp.us-east-1.rds.amazonaws.com:5432"
              name="postgres"
              role="database/creds/order"
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
