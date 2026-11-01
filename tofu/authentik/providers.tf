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
}

provider "authentik" {
  url   = "https://${local.cfg.authentik_domain}"
  token = local.secret.authentik_token
}
