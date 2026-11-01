terraform {
  required_version = ">= 1.11.5"

  required_providers {
    adguard = {
      source  = "gmichels/adguard"
      version = "1.7.1"
    }
  }
}

provider "adguard" {
  host     = local.cfg.adguard_host
  username = local.cfg.adguard_username
  password = local.secret.adguard_password
  scheme   = "http"
  insecure = false
  timeout  = 10
}
