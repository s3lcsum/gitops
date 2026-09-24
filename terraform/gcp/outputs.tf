output "vault_auto_unseal" {
  description = "Vault GCP KMS auto-unseal: service account email, base64-encoded JSON key (decode for credentials file), and KMS key resource ID for seal config"
  value = {
    service_account_email   = google_service_account.vault.email
    service_account_key_b64 = google_service_account_key.vault.private_key
    kms_key_id              = google_kms_crypto_key.vault.id
  }
  sensitive = true
}

output "github_actions_tofu" {
  description = "GitHub Actions OpenTofu CI SA: email + base64 JSON key (decode → GCP_SA_KEY secret)"
  value = {
    service_account_email   = google_service_account.github_actions_tofu.email
    service_account_key_b64 = google_service_account_key.github_actions_tofu.private_key
  }
  sensitive = true
}
