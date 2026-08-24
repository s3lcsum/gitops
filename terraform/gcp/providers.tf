terraform {
  required_version = ">= 1.11.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.45.0"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-gcp"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
