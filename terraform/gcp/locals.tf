locals {
  vault_kms = {
    key_ring_name   = "vault-keyring"
    location        = "global"
    crypto_key_name = "vault-auto-unseal"
  }

  # Only APIs required for service accounts + KMS (no Storage/IAP unless you add resources that need them).
  required_apis = [
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
  ]
}
