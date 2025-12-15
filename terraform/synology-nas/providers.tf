terraform {
  required_version = ">= 1.11.0"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "1.20.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }

  cloud {
    workspaces {
      name = "gitops-synology-nas"
    }
  }
}

provider "restapi" {
  uri                  = "https://${var.synology_host}:5001"
  insecure             = var.synology_insecure_skip_verify
  username             = var.synology_username
  password             = var.synology_password
  write_returns_object = true

  headers = {
    "Content-Type" = "application/x-www-form-urlencoded"
  }

  # Synology API requires session-based authentication
  create_returns_object = true
}
