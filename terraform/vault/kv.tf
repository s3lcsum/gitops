resource "vault_mount" "kv" {
  path        = "kv"
  description = "Secrets for infrastructure, Terraform, and applications"
  type        = "kv"
  options     = { version = "2" }
}

# Store all Authentik oAuth2 application credentials in Vault
resource "vault_kv_secret_v2" "oauth2" {
  for_each = nonsensitive(data.tfe_outputs.authentik.values.applications)

  mount               = vault_mount.kv.path
  name                = "${each.key}/authentik/oauth2"
  data_json           = jsonencode(each.value)
  options             = { version = "2" }
  delete_all_versions = true # Full deletion of the secret
}
