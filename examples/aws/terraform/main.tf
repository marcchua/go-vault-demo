provider "aws" {
  region = "${var.aws_region}"
}

provider "vault" {
  address = "${var.vault_scheme}://${var.vault_host}:${var.vault_port}"
}
