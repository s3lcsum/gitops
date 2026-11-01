output "github_actions_tofu" {
  description = "GitHub Actions OpenTofu CI SA: email + base64 JSON key (decode → GCP_SA_KEY secret)"
  value = {
    service_account_email   = google_service_account.github_actions_tofu.email
    service_account_key_b64 = google_service_account_key.github_actions_tofu.private_key
  }
  sensitive = true
}
