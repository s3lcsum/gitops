terraform {
  required_version = ">= 1.11.5"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "5.8.0"
    }
  }
}

provider "netbox" {
  server_url = local.secret.netbox_url
  api_token  = local.secret.netbox_api_token
}
