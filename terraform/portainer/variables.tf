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

variable "portainer_oauth2" {
  description = "Portainer OAuth2 configuration"
  type = object({
    access_token_uri  = optional(string)
    authorization_uri = optional(string)
    client_id         = optional(string)
    client_secret     = optional(string)
    logout_uri        = optional(string)
    redirect_uri      = optional(string)
    resource_uri      = optional(string)
  })
  default   = {}
  sensitive = true
}
