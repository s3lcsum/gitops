variable "organization_name" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "dominiksiejak"
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID for VCS integration"
  type        = string
  default     = ""
}
