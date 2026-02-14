terraform {
  required_version = ">= 1.11.0"

  required_providers {
    routeros = {
      source  = "terraform-routeros/routeros"
      version = "1.98.0"
    }
    wireguard = {
      source  = "OJFord/wireguard"
      version = "0.4.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-routeros"
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
