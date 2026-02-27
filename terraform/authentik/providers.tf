terraform {
  required_version = ">= 1.11.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
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
