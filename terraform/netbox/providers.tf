terraform {
  required_version = ">= 1.11.5"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "5.8.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "netbox"
    }
  }
}

provider "netbox" {
  server_url = var.netbox_url
  api_token  = var.netbox_api_token
}
