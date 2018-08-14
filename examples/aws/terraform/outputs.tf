output "go-iam-alb" {
  value = "${aws_lb.go-iam.dns_name}"
}

output "go-ec2-alb" {
  value = "${aws_lb.go-ec2.dns_name}"
}
