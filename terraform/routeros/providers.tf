terraform {
  required_version = ">= 1.11.5"

  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "1.99.1"
    }
    wireguard = {
      source  = "OJFord/wireguard"
      version = "0.4.1+2"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "routeros"
    }
  }
}

provider "routeros" {
  hosturl  = var.routeros_host
  username = var.routeros_username
  password = var.routeros_password
}

provider "wireguard" {
}
