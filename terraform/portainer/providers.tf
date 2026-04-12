terraform {
  required_version = ">= 1.11.5"

  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "1.27.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.76.2"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-portainer"
    }
  }
}

provider "portainer" {
  endpoint        = var.portainer_endpoint
  api_key         = var.portainer_api_key
  skip_ssl_verify = true
}
