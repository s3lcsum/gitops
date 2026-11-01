terraform {
  required_version = ">= 1.11.5"

  required_providers {
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "0.60.0"
    }
  }
}

provider "unifi" {
  api_url  = local.cfg.unifi_api_url
  username = local.secret.unifi_username
  password = local.secret.unifi_password
  site     = local.cfg.unifi_site

  # Traefik terminates TLS with a public cert; keep verify on.
  allow_insecure = false
}
