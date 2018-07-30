variable "azure_env" {}
variable "azure_location" {}
variable "azure_image_name" {}
variable "azure_image_resource_group" {}

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
