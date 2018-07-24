# go-vault-demo

Go example for multi-cloud auth, dynamic secrets, and encryption with HashiCorp Vault.

----

## Demo Instruction

This repository also provides example deployments on various platforms:

- [GCP](examples/gcp)
<br>

### Setup

You can run the sample as a standalone Go application. You will need a Vault instance and a Postgres instance to get started.

1. Run the [Postgres script](scripts/postgres.sql) at your Postgres instance.
2. Run the [Vault script](scripts/vault.sh) at your Vault instance.
3. Update the [config.toml](config.toml) file for your environment.
4. Run the Go application.
5. Try the API.



### API

- Get Orders
```
$ curl -s -X GET \
   http://localhost:3000/api/orders | jq
[
  {
    "id": 204,
    "customerName": "Lance",
    "productName": "Vault-Ent",
    "orderDate": 1523656082215
  }
]
```
- Create Order
```
$ curl -s -X POST \
   http://localhost:3000/api/orders \
   -H 'content-type: application/json' \
   -d '{"customerName": "Lance", "productName": "Vault-Ent"}' | jq
{
  "id": 204,
  "customerName": "Lance",
  "productName": "Vault-Ent",
  "orderDate": 1523656082215
}
```
- Delete Orders
```
$ curl -s -X DELETE -w "%{http_code}" http://localhost:3000/api/orders | jq
200
