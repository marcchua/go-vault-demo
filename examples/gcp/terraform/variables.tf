variable "gcp_project" {}
variable "gcp_region" {}
variable "gcp_zone" {}
variable "gcp_image" {}
variable "gcp_env" {}
variable "gcp_instances" {
  default = "1"
}

variable "vault_host" {}
variable "vault_port" {}
variable "vault_scheme" {}

variable "postgres_host" {}
variable "postgres_port" {
  default = "5432"
}
variable "postgres_database" {
  default = "postgres"
}
