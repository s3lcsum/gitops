output "github_actions_tofu" {
  description = "Deprecated name: same SA used for all keyless CI (GitHub + GitLab WIF)."
  value = {
    service_account_email = google_service_account.github_actions_tofu.email
  }
}

output "cicd_wif" {
  description = "Wire into GitHub repo variables / GitLab CI variables (no JSON keys)."
  value = {
    service_account_email = google_service_account.github_actions_tofu.email
    github = {
      workload_identity_provider = google_iam_workload_identity_pool_provider.github.name
      id_token_audience          = "https://iam.googleapis.com/${google_iam_workload_identity_pool_provider.github.name}"
    }
    gitlab = {
      workload_identity_provider = google_iam_workload_identity_pool_provider.gitlab.name
      id_token_audience          = "https://iam.googleapis.com/${google_iam_workload_identity_pool_provider.gitlab.name}"
    }
    openbao_gcp_auth = {
      role     = local.cfg.cicd_openbao_gcp_role
      audience = local.cfg.cicd_openbao_gcp_audience
    }
  }
}
