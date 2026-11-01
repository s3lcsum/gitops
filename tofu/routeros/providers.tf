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
}

provider "routeros" {
  hosturl  = local.secret.routeros_host
  username = local.secret.routeros_username
  password = local.secret.routeros_password
}

provider "wireguard" {
}
