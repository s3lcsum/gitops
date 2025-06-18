terraform {
  required_version = ">= 1.11.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.6.0"
    }
  }

  cloud {
    workspaces {
      name = "gitops-authentik"
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}


resource "authentik_system_settings" "settings" {
  # Actually I'm going to use all defaults here,
  # but still need the resoruces to make sure all
  # that all settings are set
}
