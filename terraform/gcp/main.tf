# Vault Service Account
resource "google_service_account" "vault" {
  account_id   = "vault-auto-unseal"
  display_name = "Vault Auto-Unseal SA"
  project      = var.gcp_project_id
}

# Vault Service Account Key
resource "google_service_account_key" "vault" {
  service_account_id = google_service_account.vault.name
}

# N8n Service Account
resource "google_service_account" "n8n" {
  account_id   = local.n8n_service_account.account_id
  display_name = local.n8n_service_account.display_name
  description  = local.n8n_service_account.description
  project      = var.gcp_project_id
}

# N8n Service Account Key
resource "google_service_account_key" "n8n" {
  service_account_id = google_service_account.n8n.name
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
}

# KMS Key Ring
resource "google_kms_key_ring" "vault" {
  name     = local.vault_kms.key_ring_name
  location = local.vault_kms.location
  project  = var.gcp_project_id

  depends_on = [google_project_service.apis["cloudkms.googleapis.com"]]
}

# KMS Crypto Key
resource "google_kms_crypto_key" "vault" {
  name     = local.vault_kms.crypto_key_name
  key_ring = google_kms_key_ring.vault.id

  lifecycle {
    prevent_destroy = true
  }
}

# IAM Binding for Vault SA to use the Key
resource "google_kms_crypto_key_iam_binding" "vault_encrypter_decrypter" {
  crypto_key_id = google_kms_crypto_key.vault.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_service_account.vault.email}",
  ]
}

# IAM Binding for Vault SA to view the Key
resource "google_kms_crypto_key_iam_binding" "vault_viewer" {
  crypto_key_id = google_kms_crypto_key.vault.id
  role          = "roles/cloudkms.viewer"

  members = [
    "serviceAccount:${google_service_account.vault.email}",
  ]
}

########################################################
# GOOGLE OAUTH FOR AUTHENTIK SSO
########################################################
resource "google_iap_brand" "homelab" {
  support_email     = "dreewniak@gmail.com"
  application_title = "HomeLab SSO"
  project           = var.gcp_project_id

  depends_on = [google_project_service.apis["iap.googleapis.com"]]
}

resource "google_iap_client" "authentik" {
  display_name = "Authentik SSO"
  brand        = google_iap_brand.homelab.name
}

########################################################
# REMOTE STATE (OpenTofu / Terraform GCS backend)
# Locking is handled by the gcs backend (object generation).
########################################################
resource "google_service_account" "terraform_state" {
  account_id   = "terraform-state"
  display_name = "OpenTofu remote state (GCS)"
  description  = "Used by automation or humans with impersonation to read/write tfstate in GCS"
  project      = var.gcp_project_id
}

# Homelab: Google-managed encryption and access logs are sufficient for state; dedicated CMEK and log sinks add cost.
#trivy:ignore:AVD-GCP-0066
#trivy:ignore:AVD-GCP-0077
resource "google_storage_bucket" "terraform_state" {
  name                        = local.tfstate_bucket_name
  project                     = var.gcp_project_id
  location                    = "EU"
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.apis["storage.googleapis.com"]]

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_storage_bucket_iam_member" "terraform_state_sa" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_state.email}"
}
