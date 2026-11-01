# Shared Terragrunt config for tofu/<module> units.
# Provider secrets: OpenBao KV via ephemeral vault_kv_secret_v2 (never in state).
# Non-secret defaults: each module config.tf → local.cfg.
# No tfvars.

terraform_binary = "tofu"

locals {
  module_name = basename(get_terragrunt_dir())
}

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-${local.module_name}"
  }
}

# AppRole: ~/.config/openbao/{role_id,secret_id}
# KV: secret/terraform_env/<module> flat keys; nested maps/lists = native JSON objects.
generate "vault" {
  path      = "vault_env.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "vault" {
      address = "https://bao.dominiksiejak.pl"

      auth_login {
        path = "auth/approle/login"
        parameters = {
          role_id   = trimspace(file("$${pathexpand("~/.config/openbao/role_id")}"))
          secret_id = trimspace(file("$${pathexpand("~/.config/openbao/secret_id")}"))
        }
      }
    }

    ephemeral "vault_kv_secret_v2" "module_env" {
      mount = "secret"
      name  = "terraform_env/${local.module_name}"
    }

    locals {
      # Ephemeral — provider configs + write-only attrs ONLY (not regular resources).
      secret = {
        for k, v in ephemeral.vault_kv_secret_v2.module_env.data : k => try(jsondecode(v), v)
        if !startswith(k, "__")
      }
    }
  EOF
}
