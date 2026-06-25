variable "gitea_token" {
  description = "Gitea API token (or password if username is provided)"
  type        = string
  sensitive   = true
  default     = null
}

variable "gitea_username" {
  description = "Gitea username (or token if no password is provided)"
  type        = string
  default     = null
}

variable "gitea_password" {
  description = "Gitea password (or token if no username is provided)"
  type        = string
  sensitive   = true
  default     = null
}

variable "github_token" {
  description = "GitHub PAT (repo scope) used to clone private own-repos into Gitea mirrors"
  type        = string
  sensitive   = true
  default     = null
}
