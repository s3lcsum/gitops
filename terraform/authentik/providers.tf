terraform {
  required_version = ">= 1.11.5"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-authentik"
  }
}

provider "authentik" {
  url   = "https://${var.authentik_domain}"
  token = var.authentik_token
}
