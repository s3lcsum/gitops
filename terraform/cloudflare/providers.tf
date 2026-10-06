terraform {
  required_version = ">= 1.11.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "cloudflare"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
