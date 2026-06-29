terraform {
  required_version = ">= 1.11.5"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "5.3.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-netbox"
    }
  }
}

provider "netbox" {
  server_url = var.netbox_url
  api_token  = var.netbox_api_token
}
