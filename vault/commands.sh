#!/bin/bash
vault auth enable userpass
vault login -method=userpass username=haisum

vault write auth/userpass/users/haisum \
    policies=app-app1 password=str0ng

vault write -f sops/keys/app1

vault secrets enable -path=sops transit

sops app1/microservice1.yml

sops -e -i spinnaker/kubeconfig.yml

vault policy write spinnaker-kv-ro spinnaker-kv-ro.hcl
