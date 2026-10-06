terraform {
  required_version = ">= 1.11.5"

  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "0.14.0"
    }
  }

  backend "remote" {
    hostname     = "terrakube-api.dominiksiejak.pl"
    organization = "HomeLab"
    workspaces {
      name = "backblaze"
    }
  }
}

provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}
