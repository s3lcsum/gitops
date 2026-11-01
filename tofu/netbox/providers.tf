terraform {
  required_version = ">= 1.11.5"

  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "5.8.0"
    }
  }
}

provider "netbox" {
  server_url = local.secret.netbox_url
  # TF_API_TOKEN is the live NetBox v2 token; netbox_api_token in KV often drifts.
  api_token = coalesce(
    try(local.secret.TF_API_TOKEN, null),
    try(local.secret.netbox_api_token, null),
  )
}
