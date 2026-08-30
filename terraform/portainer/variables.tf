variable "portainer_endpoint" {
  description = "URL of the Portainer instance (e.g. https://portainer.dominiksiejak.pl). '/api' will be appended automatically if missing. Prefer the Traefik hostname so TLS verifies; avoid https://IP:9443 except for bootstrap."
  type        = string
}

variable "portainer_skip_ssl_verify" {
  description = "Skip TLS verification for the Portainer API. Keep false when using https://portainer.dominiksiejak.pl. Only true for the self-signed https://192.168.89.253:9443 bootstrap endpoint."
  type        = bool
  default     = false
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
  description = "Enable OAuth/OIDC authentication via Authentik (auth.dominiksiejak.pl). Reads credentials from the gitops-authentik workspace outputs. Set to false only when bootstrapping before that workspace exists."
  type        = bool
  default     = true
}
