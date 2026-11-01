# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
locals {
  cfg = {
    gcp_project_id = "dominiksiejak"
    gcp_region     = "us-central1"
  }
}
