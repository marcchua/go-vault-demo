resource "consul_intention" "go" {
  source_name      = "go"
  destination_name = "postgres"
  action           = "allow"
}
