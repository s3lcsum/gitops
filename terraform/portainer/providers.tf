terraform {
  required_version = ">= 1.11.0"

  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "1.10.0"
    }
  }

  cloud {
    workspaces {
      name = "gitops-portainer"
    }
  }
}

provider "portainer" {
  skip_ssl_verify = true
}
