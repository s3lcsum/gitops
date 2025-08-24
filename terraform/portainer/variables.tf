variable "endpoint_id" {
  description = "Portainer Environment's endpoint ID"
  type        = number
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
