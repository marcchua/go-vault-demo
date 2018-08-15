# spring-vault-demo-nomad

This folder will help you deploy the sample app to Nomad.

We've included sample Nomad file for Go to help you deploy this application. There is also a sample Fabio job file to support a Consul-aware load balancing pattern.

We need to add entries to Consul and for this job to run.

```
consul kv put postgres/host localhost
```

Alternatively you can supply the Vault address and Postgres address directly in the job files are strings. Below is an example if your Postgres instance is exposed as a Consul service.

```
[database]
host="postgres.service.consul"
port="5432"
name="postgres"
mount="database"
role="order"
[vault]
host="active.vault.service.consul"
port="8200"
scheme="http"
authentication="token"
role="order"
```
