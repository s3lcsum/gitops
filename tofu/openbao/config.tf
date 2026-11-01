# OpenBao cannot read its own KV before authenticating, so the provider block
# lives here (AppRole files) instead of in Terragrunt's generated vault_env.tf.
# The ephemeral KV read still comes from vault_env.tf and is valid after login.
locals {
  cfg = {
    vault_addr     = "https://bao.dominiksiejak.pl"
    oidc_client_id = "openbao"
  }

  # Client secret lives in authentik state (random_password); KV must not drift from it.
  oidc_client_secret            = data.terraform_remote_state.authentik.outputs.applications["openbao"].client_secret
  oidc_client_secret_wo_version = parseint(substr(sha256(nonsensitive(local.oidc_client_secret)), 0, 8), 16)
}
