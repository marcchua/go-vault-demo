variable "k8s_instances" {
  default = 0
 }

variable "vault_host" {
  default = "localhost"
}

variable "vault_port" {
  default = "8200"
}

variable "vault_scheme" {
  default = "http"
}

variable "vault_role" {
  default = "order"
}

variable "vault_mount" {
  default = "kubernetes"
}

variable "postgres_host" {
  default = "localhost"
}

variable "postgres_port" {
  default = "5432"
}

variable "postgres_mount" {
  default = "database"
}

variable "postgres_instance" {
  default = "postgres"
}

variable "postgres_role" {
  default = "order"
}

variable "go_docker_container" {}
