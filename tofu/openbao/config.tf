# OpenBao cannot read its own KV before authenticating, so the provider block
# lives here (AppRole files) instead of in Terragrunt's generated vault_env.tf.
# The ephemeral KV read still comes from vault_env.tf and is valid after login.
locals {
  cfg = {
    vault_addr     = "https://bao.dominiksiejak.pl"
    oidc_client_id = "openbao"
  }
}
