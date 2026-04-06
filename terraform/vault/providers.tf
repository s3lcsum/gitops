terraform {
  required_version = ">= 1.11.5"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-vault"
  }
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}
