variable aws_region {}
variable aws_ami {}
variable aws_env {}
variable "aws_instances" {
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
