terraform {
  required_version = ">= 1.11.5"

  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "0.14.1"
    }
  }
}

provider "b2" {
  application_key_id = local.secret.b2_application_key_id
  application_key    = local.secret.b2_application_key
}
