locals {
  # Globally unique GCS bucket name for OpenTofu/Terraform state (must match backend blocks).
  tfstate_bucket_name = "dominiksiejak-gitops-tfstate"

  vault_kms = {
    key_ring_name   = "vault-keyring"
    location        = "global"
    crypto_key_name = "vault-auto-unseal"
  }

  n8n_service_account = {
    account_id   = "n8n-workflows"
    display_name = "N8n Workflows SA"
    description  = "Service account for N8n workflow automation"
  }

  required_apis = [
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",
    "storage.googleapis.com",
  ]
}
