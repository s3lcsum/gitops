resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.gcp_project_id
  service            = each.value
  disable_on_destroy = false
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

########################################################
# GitHub Actions OpenTofu CI (JSON key → GH secret GCP_SA_KEY)
########################################################
resource "google_service_account" "github_actions_tofu" {
  account_id   = "github-actions-tofu"
  display_name = "GitHub Actions OpenTofu CI"
  description  = "CI runner for plan/apply against GCS tfstate (key exported to GitHub Actions secret)"
  project      = var.gcp_project_id
}

resource "google_service_account_key" "github_actions_tofu" {
  service_account_id = google_service_account.github_actions_tofu.name
}

resource "google_storage_bucket_iam_member" "github_actions_tofu_state" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_actions_tofu.email}"
}
