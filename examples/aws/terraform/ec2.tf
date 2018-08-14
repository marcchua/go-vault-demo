data "aws_ami" "go" {
  most_recent = true
  owners     = ["self"]

  filter {
    name   = "image-id"
    values = ["${var.aws_ami}"]
  }

}

resource "aws_key_pair" "go" {
  key_name   = "${var.aws_env}"
  public_key = "${tls_private_key.go.public_key_openssh}"
}

resource "aws_launch_configuration" "go_iam" {
  name          = "${var.aws_env}-iam-launch-config"
  image_id      = "${data.aws_ami.go.id}"
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.go.name}"
  key_name = "${aws_key_pair.go.key_name}"
  security_groups = ["${aws_security_group.go_app.id}"]
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<SCRIPT
#!/bin/bash
cat << EOF > /app/config.toml
[database]
host="${var.postgres_host}"
port="${var.postgres_port}"
name="${var.postgres_database}"
mount="database"
role="order"
[vault]
host="${var.vault_host}"
mount="aws-iam"
port="${var.vault_port}"
scheme="${var.vault_scheme}"
authentication="aws-iam"
role="order"
EOF
systemctl enable go.service
service go restart
SCRIPT

}

resource "aws_autoscaling_group" "go_iam" {
  name                 = "${var.aws_env}-iam-asg"
  launch_configuration = "${aws_launch_configuration.go_iam.name}"
  desired_capacity = "${var.aws_instances}"
  min_size             = 1
  max_size             = 10
  vpc_zone_identifier = ["${module.vpc.public_subnets}"]
  target_group_arns = ["${aws_lb_target_group.go-iam.id}"]

  lifecycle {
    create_before_destroy = true
  }


  tags = [
      {
        key                 = "env"
        value               = "${var.aws_env}"
        propagate_at_launch = true
      }
    ]

}

resource "aws_launch_configuration" "go_ec2" {
  name          = "${var.aws_env}-ec2-launch-config"
  image_id      = "${data.aws_ami.go.id}"
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.go.name}"
  key_name = "${aws_key_pair.go.key_name}"
  security_groups = ["${aws_security_group.go_app.id}"]
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<SCRIPT
#!/bin/bash
cat << EOF > /app/config.toml
[database]
host="${var.postgres_host}"
port="${var.postgres_port}"
name="${var.postgres_database}"
mount="database"
role="order"
[vault]
host="${var.vault_host}"
mount="aws-ec2"
port="${var.vault_port}"
scheme="${var.vault_scheme}"
authentication="aws-ec2"
role="order"
EOF
systemctl enable go.service
service go restart
SCRIPT

}

resource "aws_autoscaling_group" "go_ec2" {
  name                 = "${var.aws_env}-ec2-asg"
  launch_configuration = "${aws_launch_configuration.go_ec2.name}"
  desired_capacity = "${var.aws_instances}"
  min_size             = 1
  max_size             = 10
  vpc_zone_identifier = ["${module.vpc.public_subnets}"]
  target_group_arns = ["${aws_lb_target_group.go-ec2.id}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = [
      {
        key                 = "env"
        value               = "${var.aws_env}"
        propagate_at_launch = true
      }
    ]

}
