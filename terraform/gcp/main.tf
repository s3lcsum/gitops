# Vault auto-unseal: KMS + dedicated service account (minimal billable surface; KMS is typically cents/month for homelab).
resource "google_service_account" "vault" {
  account_id   = "vault-auto-unseal"
  display_name = "Vault Auto-Unseal SA"
  project      = var.gcp_project_id
}

resource "google_service_account_key" "vault" {
  service_account_id = google_service_account.vault.name
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_kms_key_ring" "vault" {
  name     = local.vault_kms.key_ring_name
  location = local.vault_kms.location
  project  = var.gcp_project_id

  depends_on = [google_project_service.apis["cloudkms.googleapis.com"]]
}

resource "google_kms_crypto_key" "vault" {
  name     = local.vault_kms.crypto_key_name
  key_ring = google_kms_key_ring.vault.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_binding" "vault_encrypter_decrypter" {
  crypto_key_id = google_kms_crypto_key.vault.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_service_account.vault.email}",
  ]
}

resource "google_kms_crypto_key_iam_binding" "vault_viewer" {
  crypto_key_id = google_kms_crypto_key.vault.id
  role          = "roles/cloudkms.viewer"

  members = [
    "serviceAccount:${google_service_account.vault.email}",
  ]
}
