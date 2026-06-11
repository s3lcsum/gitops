variable "portainer_endpoint" {
  description = "URL of the Portainer instance (e.g. https://portainer.example.com). '/api' will be appended automatically if missing."
  type        = string
}

variable "endpoint_id" {
  description = "Portainer Environment's endpoint ID"
  type        = number
  default     = 1
}

variable "portainer_api_key" {
  description = "Portainer API key for authentication. Either this or api_user/api_password must be provided."
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_oauth" {
  description = "Enable OAuth/OIDC authentication via Authentik (auth.lake.dominiksiejak.pl). Reads credentials from the gitops-authentik workspace outputs. Set to false only when bootstrapping before that workspace exists."
  type        = bool
  default     = true
}
