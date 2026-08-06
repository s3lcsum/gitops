terraform {
  required_version = ">= 1.11.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.52.8"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
  }

  cloud {
    hostname     = "app.terraform.io"
    organization = "dominiksiejak"

    workspaces {
      name = "gitops-cloudflare"
    }
  }
}

provider "cloudflare" {
  # Use CLOUDFLARE_API_TOKEN env var or TF_VAR_cloudflare_api_token
}
