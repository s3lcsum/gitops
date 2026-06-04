terraform {
  required_version = ">= 1.12.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.11.0"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-kind"
  }
}

provider "kind" {}
