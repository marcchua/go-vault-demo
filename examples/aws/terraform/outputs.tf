output "go-iam" {
  value = "${aws_instance.go-iam.*.public_dns}"
}


output "ec2-iam" {
  value = "${aws_instance.go-ec2.*.public_dns}"
}
