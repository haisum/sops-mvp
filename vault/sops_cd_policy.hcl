path "sops/encrypt/spinnaker" {
  capabilities = [ "update" ]
}
path "sops/decrypt/spinnaker" {
  capabilities = [ "update" ]
}
path "sops/encrypt/app1" {
  capabilities = [ "update" ]
}
path "sops/decrypt/app1" {
  capabilities = [ "update" ]
}
path "secret/data/spinnaker/*" {
    capabilities = ["create", "update"]
}
path "secret/data/app1/*" {
    capabilities = ["create", "update"]
}