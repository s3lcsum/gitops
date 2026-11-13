# Keyless CI: GitHub Actions + GitLab OIDC → one GCP SA (GCS tfstate + OpenBao GCP auth JWT).
# After apply: set GitHub repo variables GCP_WORKLOAD_IDENTITY_PROVIDER, GCP_SERVICE_ACCOUNT
# from output cicd_wif. GitLab: same values in CI/CD variables.

data "google_project" "current" {
  project_id = local.cfg.gcp_project_id
}

resource "google_iam_workload_identity_pool" "cicd" {
  project                   = local.cfg.gcp_project_id
  workload_identity_pool_id = local.cfg.cicd_wif_pool_id
  display_name              = "Homelab OpenTofu CI"
  description               = "GitHub Actions and GitLab CI federation (no SA JSON keys)"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = local.cfg.gcp_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.cicd.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  attribute_condition = "assertion.repository_owner == \"${local.cfg.cicd_github_repository_owner}\" && assertion.repository == \"${local.cfg.cicd_github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_iam_workload_identity_pool_provider" "gitlab" {
  project                            = local.cfg.gcp_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.cicd.workload_identity_pool_id
  workload_identity_pool_provider_id = "gitlab"
  display_name                       = "GitLab.com"

  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.project_path" = "assertion.project_path"
    "attribute.ref"          = "assertion.ref"
    "attribute.ref_type"     = "assertion.ref_type"
  }
  attribute_condition = "assertion.project_path == \"${local.cfg.cicd_gitlab_project_path}\""

  oidc {
    issuer_uri = "https://gitlab.com"
  }
}

resource "google_service_account_iam_member" "cicd_github_wif" {
  service_account_id = google_service_account.github_actions_tofu.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.cicd.name}/attribute.repository/${local.cfg.cicd_github_repository}"
}

resource "google_service_account_iam_member" "cicd_gitlab_wif" {
  service_account_id = google_service_account.github_actions_tofu.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.cicd.name}/attribute.project_path/${local.cfg.cicd_gitlab_project_path}"
}

# Mint OIDC JWTs for OpenBao auth/gcp/login from federated CI credentials.
resource "google_service_account_iam_member" "cicd_openid_token_self" {
  service_account_id = google_service_account.github_actions_tofu.name
  role               = "roles/iam.serviceAccountOpenIdTokenCreator"
  member             = "serviceAccount:${google_service_account.github_actions_tofu.email}"
}

# Local operator: same ID-token-only grant so `make auth` works from a
# workstation without AppRole files. No access tokens and no SA keys.
resource "google_service_account_iam_member" "cicd_openid_token_local_operator" {
  service_account_id = google_service_account.github_actions_tofu.name
  role               = "roles/iam.serviceAccountOpenIdTokenCreator"
  member             = local.cfg.cicd_local_operator_member
}
