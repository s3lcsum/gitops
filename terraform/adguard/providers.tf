terraform {
  required_version = ">= 1.11.5"

  required_providers {
    adguard = {
      source  = "gmichels/adguard"
      version = "1.7.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "adguard"
    }
  }
}

provider "adguard" {
  host     = var.adguard_host
  username = var.adguard_username
  password = var.adguard_password
  scheme   = "http"
  insecure = false
  timeout  = 10
}
