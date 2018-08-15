provider "aws" {
  region = "${var.aws_region}"
}

resource "random_string" "password" {
  length = 32
  special = false
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = "${data.aws_vpc.default.id}"
}

data "aws_security_group" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
  name   = "default"
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${var.aws_env}db"

  engine            = "postgres"
  engine_version    = "9.6.3"
  instance_class    = "db.t2.large"
  allocated_storage = 5
  storage_encrypted = false

  name = "${var.aws_env}db"
  username = "postgres"
  password = "${random_string.password.result}"
  port     = "5432"

  publicly_accessible = true
  vpc_security_group_ids = ["${data.aws_security_group.default.id}"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster
  backup_retention_period = 0

  tags = {
    Owner       = "${var.aws_env}"
  }

  # DB subnet group
  subnet_ids = ["${data.aws_subnet_ids.all.ids}"]

  # DB parameter group
  family = "postgres9.6"

  # DB option group
  major_engine_version = "9.6"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "${var.aws_env}db"
}
