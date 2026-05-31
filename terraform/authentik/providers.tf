terraform {
  required_version = ">= 1.11.5"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-authentik"
    }
  }
}

provider "authentik" {
  url   = "https://${var.authentik_domain}"
  token = var.authentik_token
}
