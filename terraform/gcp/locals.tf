locals {
  vault_kms = {
    key_ring_name   = "vault-keyring"
    location        = "global"
    crypto_key_name = "vault-auto-unseal"
  }

  # Globally unique GCS bucket name for OpenTofu/Terraform state (must match backend blocks in terraform/*/providers.tf).
  tfstate_bucket_name = "dominiksiejak-gitops-tfstate"

  # Only APIs required for service accounts + KMS + state storage.
  required_apis = [
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
  ]
}
