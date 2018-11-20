# go-vault-demo-connect

[Connect Sidecar](https://www.consul.io/docs/platform/k8s/connect.html) example running on Kubernetes.

Run the additional [vault script](vault.sh) in this folder to configure the Kubernetes trust relationship with Vault.

An example configmap is included for you to deploy to an existing Kubernetes cluster. The workload is modeled as code in the [go.tf](terraform/go.tf) terraform file.

Consul connect injection must be enabled in your cluster to run this example.
