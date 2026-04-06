terraform {
  required_version = ">= 1.11.5"

  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "0.7.0"
    }
  }

  backend "gcs" {
    bucket = "dominiksiejak-gitops-tfstate"
    prefix = "gitops-gitea"
  }
}

provider "gitea" {
  base_url = "https://git.lake.dominiksiejak.pl"
  token    = var.gitea_token
  username = var.gitea_username
  password = var.gitea_password
}
