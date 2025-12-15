terraform {
  required_version = ">= 1.11.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.10.1"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.61.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
  }

  cloud {
    workspaces {
      name = "gitops-authentik"
    }
  }
}

provider "authentik" {
  url   = "https://auth.lake.dominiksiejak.pl"
  token = var.authentik_token
}
