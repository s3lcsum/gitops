locals {
  # Globally unique GCS bucket name for OpenTofu/Terraform state (must match backend blocks in terraform/*/providers.tf).
  tfstate_bucket_name = "dominiksiejak-gitops-tfstate"

  # APIs required for service accounts + state storage.
  required_apis = [
    "iam.googleapis.com",
    "storage.googleapis.com",
  ]
}
