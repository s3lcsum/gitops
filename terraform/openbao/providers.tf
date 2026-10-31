terraform {
  required_version = ">= 1.11.5"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.13.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "openbao"
    }
  }
}

provider "vault" {
  address = var.vault_addr

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.approle_role_id
      secret_id = var.approle_secret_id
    }
  }
}
