terraform {
  required_version = ">= 1.11.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.12.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-gcp"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}