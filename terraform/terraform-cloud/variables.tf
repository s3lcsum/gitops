variable "organization_name" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "dominiksiejak"
}

variable "github_oauth_token_id" {
  description = "GitHub OAuth token ID for VCS integration"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository for GitOps"
  type        = string
  default     = "s3lcsum/gitops"
}
