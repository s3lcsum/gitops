terraform {
  required_version = ">= 1.11.5"

  required_providers {
    portainer = {
      source  = "portainer/portainer"
      version = "1.34.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-portainer"
  }
}

provider "portainer" {
  endpoint = var.portainer_endpoint
  api_key  = var.portainer_api_key
  # Prefer https://portainer.dominiksiejak.pl (Traefik LE cert). Only set
  # portainer_skip_ssl_verify=true for the self-signed IP:9443 bootstrap URL.
  skip_ssl_verify = var.portainer_skip_ssl_verify
}
