terraform {
  required_version = ">= 1.11.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.26.0"
    }
  }

  # Bootstrap: apply once on Terraform Cloud so the bucket exists, then switch to backend "gcs"
  # below and run: tofu init -migrate-state
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
