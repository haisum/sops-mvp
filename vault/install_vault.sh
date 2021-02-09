#!/bin/bash

# installs vault on ubuntu

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault -y
export VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200
nohup vault server -dev &
echo "Vault started! This script can be closed safely now. Check logs in $PWD/nohup.out"
tail -f "$PWD/nohup.out"