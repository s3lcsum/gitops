# Shared Terragrunt config for tofu/<module> units.
# Provider secrets: OpenBao KV via ephemeral vault_kv_secret_v2 (never in state).
# Non-secret defaults: each module config.tf → local.cfg.
# No tfvars.

terraform_binary = "tofu"

terraform {
  extra_arguments "parallelism" {
    commands = [
      "apply",
      "plan",
      "destroy",
    ]
    arguments = [
      "-parallelism=${get_env("TOFU_PARALLELISM", "15")}",
    ]
  }
}

locals {
  module_name   = basename(get_terragrunt_dir())
  vault_kv_name = local.module_name
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

# VAULT_TOKEN (Google ID token login) when set. Otherwise AppRole files.
generate "vault" {
  path      = "vault_env.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "vault" {
      address = "https://bao.dominiksiejak.pl"
      token   = length(trimspace("${get_env("VAULT_TOKEN", "")}")) > 0 ? trimspace("${get_env("VAULT_TOKEN", "")}") : null

      dynamic "auth_login" {
        for_each = length(trimspace("${get_env("VAULT_TOKEN", "")}")) == 0 ? [1] : []
        content {
          path = "auth/approle/login"
          parameters = {
            role_id   = trimspace(file("$${pathexpand("~/.config/openbao/role_id")}"))
            secret_id = trimspace(file("$${pathexpand("~/.config/openbao/secret_id")}"))
          }
        }
      }
    }

    ephemeral "vault_kv_secret_v2" "module_env" {
      mount = "secret"
      name  = "${local.vault_kv_name}"
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
