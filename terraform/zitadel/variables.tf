variable "zitadel_domain" {
  description = "Zitadel server domain"
  type        = string
}

variable "zitadel_port" {
  description = "Zitadel server port"
  type        = number
}

variable "zitadel_insecure" {
  description = "Whether to use insecure connection (for development)"
  type        = bool
}

variable "org_name" {
  description = "Organization name"
  type        = string
}

variable "human_users" {
  description = "Human users configuration"
  type = map(object({
    first_name = string
    last_name  = string
    email      = string
    roles      = optional(list(string), [])
    is_owner   = optional(bool, false)
  }))
}

variable "google_sso" {
  description = "Google SSO configuration"
  type = object({
    client_id     = string
    client_secret = string
  })
  sensitive = true
}
