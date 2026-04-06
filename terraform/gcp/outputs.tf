output "service_accounts" {
  description = "Service account information"
  value = {
    vault = {
      email = google_service_account.vault.email
      key   = google_service_account_key.vault.private_key
    }
    n8n = {
      email = google_service_account.n8n.email
      key   = google_service_account_key.n8n.private_key
    }
  }
  sensitive = true
}

output "google_oauth_authentik" {
  description = "Google OAuth credentials for Authentik SSO"
  value = {
    client_id     = google_iap_client.authentik.client_id
    client_secret = google_iap_client.authentik.secret
  }
  sensitive = true
}

output "terraform_state_bucket" {
  description = "GCS bucket for OpenTofu/Terraform remote state"
  value       = google_storage_bucket.terraform_state.name
}

output "terraform_state_service_account" {
  description = "Service account that can read/write state objects in the bucket"
  value       = google_service_account.terraform_state.email
}
