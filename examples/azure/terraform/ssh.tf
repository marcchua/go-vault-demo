resource "tls_private_key" "go" {
  algorithm = "RSA"
}

resource "null_resource" "go" {
  provisioner "local-exec" {
    command = "echo \"${tls_private_key.go.private_key_pem}\" > go.pem"
  }

  provisioner "local-exec" {
    command = "chmod 600 go.pem"
  }
}
