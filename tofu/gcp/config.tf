# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
locals {
  cfg = {
    gcp_project_id = "dominiksiejak"
    gcp_region     = "us-central1"

    cicd_wif_pool_id             = "homelab-cicd"
    cicd_github_repository_owner = "s3lcsum"
    cicd_github_repository       = "s3lcsum/gitops"
    cicd_gitlab_project_path     = "s3lcsum/gitops"
    cicd_openbao_gcp_role        = "cicd-terraform"
    cicd_openbao_gcp_audience    = "vault/cicd-terraform"

    # Repo owner's workstation: ID token only (no keys) for local tofu runs.
    cicd_local_operator_member = "user:dreewniak@gmail.com"
  }
}
