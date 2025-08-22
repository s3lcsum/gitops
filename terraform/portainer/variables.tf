variable "endpoint_id" {
  description = "Portainer Environment's endpoint ID"
  type        = number
}

variable "portainer_oauth2_enabled" {
  description = "Enable OAuth2 authentication"
  type        = bool
  default     = false
}


variable "portainer_oauth2_access_token_uri" {
  description = "Portainer OAuth2 access token URI"
  type        = string
}

variable "portainer_oauth2_authorization_uri" {
  description = "Portainer OAuth2 authorization URI"
  type        = string
}

variable "portainer_oauth2_client_id" {
  description = "Portainer OAuth2 client ID"
  type        = string
}

variable "portainer_oauth2_client_secret" {
  description = "Portainer OAuth2 client secret"
  type        = string
}

variable "portainer_oauth2_logout_uri" {
  description = "Portainer OAuth2 logout URI"
  type        = string
}

variable "portainer_oauth2_redirect_uri" {
  description = "Portainer OAuth2 redirect URI"
  type        = string
}
