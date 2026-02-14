terraform {
  required_version = ">= 1.11.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.61.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-vault"
    }
  }
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}
