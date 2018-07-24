# go-vault-demo-gcp

This folder will help you deploy on GCP using the [GCE](https://www.vaultproject.io/docs/auth/gcp.html#gce) and [IAM](https://www.vaultproject.io/docs/auth/gcp.html#iam) auth methods.

### Setup

You can run the sample as a standalone Go application. You will need a Vault instance and a Postgres instance to get started.

1. Build your packer image. A [sample build script](packer/build.sh) has been provided for you. You can read more about the Packer GCP builder [here](https://www.packer.io/docs/builders/googlecompute.html).
2. Run the terraform code to push your application to GCP. [Sample variables](terraform/terraform.tfvars.example) have been provided for you.
3. Run the [Vault script](scripts/vault.sh) at your Vault.
