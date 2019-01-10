#!/bin/bash

#*****ACL Policy*****
echo 'path "transit/decrypt/order" {
  capabilities = ["update"]
}
path "transit/encrypt/order" {
  capabilities = ["update"]
}
path "database/creds/order" {
  capabilities = ["read"]
}
path "pki/issue/order" {
  capabilities = ["update"]
}' | vault policy write order -

#*****Postgres Config*****
vault secrets enable database
vault write database/config/postgresql \
  plugin_name=postgresql-database-plugin \
  allowed_roles="*" \
  connection_url="postgresql://postgres:postgres@localhost:5432/postgres?sslmode=disable"
vault write database/roles/order \
  db_name=postgresql \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\"; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

#*****Transit Config*****
vault secrets enable transit
vault write -f transit/keys/order

#*****PKI Config*****
vault secrets enable pki
vault secrets tune -max-lease-ttl=8760h pki
vault write pki/root/generate/internal \
    common_name=vault.hashidemos.io \
    ttl=8760h
vault write pki/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"
vault write pki/roles/order \
    allowed_domains=order.hashidemos.io \
    allow_bare_domains=true \
    allow_localhost=true \
    generate_lease=true \
    key_bits=4096 \
    max_ttl=72h
