terraform {
  required_version = ">= 1.11.5"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "5.2.1"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-netbox"
  }
}

provider "netbox" {
  server_url = var.netbox_url
  api_token  = var.netbox_api_token
}
