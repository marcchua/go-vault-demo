resource "aws_iam_user" "vault" {
  name = "${var.aws_env}"
}

resource "aws_iam_access_key" "vault" {
  user = "${aws_iam_user.vault.name}"
}

resource "aws_iam_user_policy" "vault_ro" {
  name = "${var.aws_env}"
  user = "${aws_iam_user.vault.name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "iam:GetInstanceProfile",
        "iam:GetUser",
        "iam:GetRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "go" {
  name = "${var.aws_env}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "go" {
  name = "${var.aws_env}"
  role = "${aws_iam_role.go.name}"
}
