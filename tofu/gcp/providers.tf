terraform {
  required_version = ">= 1.11.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }
}

provider "google" {
  project = local.cfg.gcp_project_id
  region  = local.cfg.gcp_region
}
