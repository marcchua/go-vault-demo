# go-vault-demo-azure

This folder will help you deploy on Azure using the [MSI](https://www.vaultproject.io/docs/auth/azure.html) auth method.

### Setup

1. Build your packer image. A [sample build script](packer/build.sh) has been provided for you. You can read more about the Packer Azure builder [here](https://www.packer.io/docs/builders/azure.html).
2. Run the terraform code to push your application to Azure. [Sample variables](terraform/terraform.tfvars.example) have been provided for you.
3. Run the [Vault script](scripts/vault.sh) at your Vault.
