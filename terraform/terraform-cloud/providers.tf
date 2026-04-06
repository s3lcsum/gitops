terraform {
  required_version = ">= 1.11.5"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.76.1"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-terraform-cloud"
  }
}

provider "tfe" {
}
