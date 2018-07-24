# go-vault-demo-aws

This folder will help you deploy on AWS using the [EC2](https://www.vaultproject.io/docs/auth/aws.html#ec2-auth-method) and [IAM](https://www.vaultproject.io/docs/auth/aws.html#iam-auth-method) auth methods.

### Setup

1. Build your packer image. A [sample build script](packer/build.sh) has been provided for you. You can read more about the Packer AWS builder [here](https://www.packer.io/docs/builders/amazon.html).
2. Run the terraform code to push your application to AWS. [Sample variables](terraform/terraform.tfvars.example) have been provided for you.
