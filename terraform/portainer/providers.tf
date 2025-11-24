terraform {
  required_version = ">= 1.11.0"

  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "1.17.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "portainer" {
  endpoint        = var.portainer_endpoint
  api_key         = var.portainer_api_key
  skip_ssl_verify = true
}
