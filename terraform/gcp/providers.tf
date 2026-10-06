terraform {
  required_version = ">= 1.11.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.4.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "gcp"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
