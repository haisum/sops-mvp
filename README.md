Motivation
----

Hashicorp Vault is one of the most popular tools for managing on-premises secrets. An authorized user can use the vault cli, API or UI to create or update secrets. Vault does have audit trail and versioning so most of the times they are sufficient for keeping a track of who did what and when; but sometimes, organizations need to have even more control and manage secrets using a familiar, git based workflow that is based on feature branches, reviews and merge approvals. Since Git is not really designed to store secure information, it would be insecure and a violation of security best practices to use it without some sort of mechanism to encrypt/decrypt information stored in committed files.

Mozilla SOPS is a tool for securely storing secrets in text files. It does that by encrypting/decrypting the values in these files using various types of keys. These keys may be GPG and self generated or may be provided by services such as Azure Key Vault, AWS KMS, GCP KMS or Hashicorp Vault.

Using Hashicrop Vault's transit engine, Mozilla Sops and Github Workflows, this MVP tries to demonstrate a possible solution for creating a Git based workflow for managing secrets.


Step by Step tutorial
------

This guide assumes Vault is already installed and you have root level privileges to it. We will setup a pipeline for updating secrets for two different projects. One of them is Spinnaker which is CI/CD platform and may have its own secrets managed by Ops Team Lead and the other one is App1 which may be a service composed of several microservices developed by a team or several teams led by the same Manager.

1. Install sops cli from https://github.com/mozilla/sops/releases/
2. Enable transit engine in Vault using command `vault secrets enable -path=sops transit`
3. Create two keys in Vault using commands `vault write -f sops/keys/app1` and `vault write -f sops/keys/spinnaker`
4. Create two policies for giving access to these keys: `vault policy write sops-app1 sops-app1.hcl && vault policy write sops-spinnaker sops-spinnaker.hcl` 
sops-app1.hcl
```hcl
path "sops/encrypt/app1" {
  capabilities = [ "update" ]
}
path "sops/decrypt/app1" {
  capabilities = [ "update" ]
}
```
sops-spinnaker.hcl
```hcl
path "sops/encrypt/spinnaker" {
  capabilities = [ "update" ]
}
path "sops/decrypt/spinnaker" {
  capabilities = [ "update" ]
}
```
4. Enable userpass auth on Vault `vault auth enable userpass`
5. Create two users `vault write auth/userpass/users/haisum policies=sops-app1 password=<password here>` and `vault write auth/userpass/users/brian policies=sops-spinnaker password=<password here>`
6. Notice that user `haisum` can only access app1 key and `brian` can only access `spinnaker` key. Here `haisum` would be a team lead for app1 and will have access to app1 secrets and `brian` would be Ops team lead and have access to all Spinnaker secrets.
7. Create some directories `mkdir -p sops/secrets/app1 sops/secrets/spinnaker sops/.github/workflows`. Now create a file `.sops.yaml` in the directory `sops` with following contents:
```yaml
creation_rules:
  - path_regex: secrets/app1/*
    hc_vault_transit_uri: "http://<VAULT HOST HERE>:8200/v1/sops/keys/app1"
  - path_regex: secrets/spinnaker/*
    hc_vault_transit_uri: "http://<VAULT HOST HERE>:8200/v1/sops/keys/spinnaker"
destination_rules:
  - vault_path: "app1/"
    vault_kv_mount_name: "secret/" # default
    vault_kv_version: 2 # default
    path_regex: secrets/app1/*
    omit_extensions: true
  - vault_path: "spinnaker/"
    vault_kv_mount_name: "secret/" # default
    vault_kv_version: 2 # default
    path_regex: secrets/spinnaker/*
    omit_extensions: true
```
8. This configuration tells sops to **a)** All secrets in secrets/app1 will use `app1` key and secrets/spinnaker will use `spinnaker` key for encryption and decryption with sops **b)** All secrets in secrets/app1 will end up at secret/app1/ in Vault and secrets/spinnaker/* will end up at secret/spinnaker in Vault.
9. Login to Vault with one of the users create in step#5. `vault login -method=userpass username=haisum`
10. Create a new secret file using sops cli `sops secrets/app1/db.yaml` with contents: `password: supersecretvalue`
11. Save the file and open it in some editor. It should look something like this:
```yaml
password: ENC[AES256_GCM,data:bX2mrR88ocxCrLXX45r3g4mnGw==,iv:6HxtWSdlZVTnar5dwczRpo+frLmbXok+TCsLor2VYbs=,tag:TbrFTTZqCEYAi4yv01Tm+w==,type:str]
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault:
    -   vault_address: http://40.122.204.70:8200
        engine_path: sops
        key_name: app1
        created_at: '2021-02-06T18:20:13Z'
        enc: vault:v1:AyQrlkrUgsrNVnJ2hQrNmtXmXNhv3L0mp8jNI8nwBChYJhuojzrzJF3LsOmc/6ybAwYrS1SLS2E+UMlr
    lastmodified: '2021-02-07T03:57:24Z'
    mac: ENC[AES256_GCM,data:AJBmlMmf+r+K/JRSvEvyeJA1+NbmGmE7NASHq047kXhVAastckBhe3RSbEXpnZHcYACEVYaSDxB/+FyP17NBhb/g0K8qVsC6VCYt2+d2mT/Og/Ven8T0v0lExjE350623bavUr2W/fdfTpF2kS3VTPJmU7QfmlGB25yxZ4llmpQ=,iv:das3Jw9JZFhzJxPFptV4mBPojvrRQCnzgVYZCCfjTvg=,tag:6IgrpuN8Y+RTg1K+CHVPnA==,type:str]
    pgp: []
    unencrypted_suffix: _unencrypted
    version: 3.6.1
```
12. Now try editing a file with `sops secrets/spinnaker/db.yaml` and saving it. You will encounter an error because user `haisum` doesn't have access to the key used for creating/updating spinnaker secrets.
13. Try publishing secret file with `sops publish secrets/app1/db.yaml` and it will fail because user `haisum` only has permissions to decrypt/encrypt using a key in Vault but doesn't have permissions to publish secrets to Vault.
14. You can come up with complicated hierarchy/file structure and restrict access to keys. In addition to creating keys per project, one can also create keys per environment or a hybrid setup or a key per environment per project with access restricted using appropriate Vault policies.
15. Once a secret file has been created or updated by an authorized user, they can create a PR to security admin who can review the changes and approve for merge. Once merged, a CI/CD platform can run a pipeline configured with highly privileged token/user and publish the updated secrets to Vault.
16. Login to Vault with root token and create a policy for CD pipeline: `vault policy write sops-cd sops-cd.hcl`
sops-cd.hcl
```hcl
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
```
17. Create a token with this policy `vault token create -policy=sops-cd`
18. Put this token in Github repository settings as value for `VAULT_TOKEN`
19. Put this workflow definion in `.github/workflows/main.yml` (change VAULT_ADDR):
```yaml
on:
  push:
    branches:
      - main
    paths:
      - "secrets/**"

jobs:
  push_to_vault:
    runs-on: ubuntu-latest
    name: Push changed files to Vault
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - id: files
        name: get modified files
        uses: jitterbit/get-changed-files@v1
      - name: Install sops
        run: |
          set -e
          curl -o sops -L https://github.com/mozilla/sops/releases/download/v3.6.1/sops-v3.6.1.linux
          chmod +x sops
          sudo mv sops /usr/local/bin/
      - name: Publish secrets
        env:
          VAULT_ADDR: http://40.122.204.70:8200
          VAULT_TOKEN: ${{ secrets.VAULT_TOKEN }}
        run: |
          set -e
          for changed_file in ${{ steps.files.outputs.added_modified }}; do
            echo "$changed_file";
            if [[ $changed_file =~ "secrets/" ]]; then
              sops publish -y "${changed_file}"
            fi
          done

```
20. Create and merge PR and it should publish the updated secrets to Vault.