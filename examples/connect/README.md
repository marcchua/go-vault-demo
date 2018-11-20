# go-vault-demo-connect

Connect example running on Kubernetes.  Consul connect injection must be enabled in your cluster to run this example. See the following resources.

- [Helm](https://www.consul.io/docs/platform/k8s/helm.html)
- [Connect Envoy Sidecar](https://www.consul.io/docs/platform/k8s/connect.html)


## Steps
1. Run the additional [vault script](vault.sh) in this folder to configure the Kubernetes trust relationship with Vault.
2. Run the [terraform example](terraform).
