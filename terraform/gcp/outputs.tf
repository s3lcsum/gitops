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

