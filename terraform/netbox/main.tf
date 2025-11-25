terraform {
  required_version = ">= 1.11.0"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 4.3.0"
    }
  }

  cloud {
    workspaces {
      name = "gitops-netbox"
    }
  }
}

provider "netbox" {
  server_url = var.netbox_url
  api_token  = var.netbox_api_token
}
