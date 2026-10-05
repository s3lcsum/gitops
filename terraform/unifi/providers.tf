terraform {
  required_version = ">= 1.11.5"

  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "0.59.0"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-unifi"
  }
}

provider "unifi" {
  api_url  = var.unifi_api_url
  username = var.unifi_username
  password = var.unifi_password
  site     = var.unifi_site

  # Traefik terminates TLS with a public cert; keep verify on.
  allow_insecure = false
}
