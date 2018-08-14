resource "aws_lb" "go-iam" {
  name               = "${var.aws_env}-go-iam-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.go_lb.id}"]
  subnets            = ["${module.vpc.public_subnets}"]

  tags {
    Environment = "${var.aws_env}-go-iam-lb"
  }

}

resource "aws_lb" "go-ec2" {
  name               = "${var.aws_env}-go-ec2-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.go_lb.id}"]
  subnets            = ["${module.vpc.public_subnets}"]

  tags {
    Environment = "${var.aws_env}-go-ec2-lb"
  }

}

resource "aws_lb_target_group" "go-iam" {
  name     = "${var.aws_env}-iam-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = "${module.vpc.vpc_id}"
  health_check {
    path   = "/health"
  }
}

resource "aws_lb_target_group" "go-ec2" {
  name     = "${var.aws_env}-ec2-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = "${module.vpc.vpc_id}"
  health_check {
    path   = "/health"
  }
}

resource "aws_lb_listener" "go_iam" {
  load_balancer_arn = "${aws_lb.go-iam.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.go-iam.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "go_ec2" {
  load_balancer_arn = "${aws_lb.go-ec2.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.go-ec2.arn}"
    type             = "forward"
  }
}
