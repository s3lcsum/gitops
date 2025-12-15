variable "authentik_token" {
  description = "Authentik API token for Terraform provider authentication"
  type        = string
  sensitive   = true
}

variable "authentik_domain" {
  description = "Authentik server domain"
  type        = string
  default     = "auth.lake.dominiksiejak.pl"
}

variable "users" {
  description = "User accounts to create in Authentik"
  type = map(object({
    name         = string
    email        = string
    groups       = list(string)
    is_active    = optional(bool, true)
    sshPublicKey = optional(list(string), [])
  }))
}

variable "service_accounts" {
  description = "Service accounts for LDAP binds with hardcoded passwords"
  type = map(object({
    name     = string
    password = string
    is_admin = optional(bool, false)
  }))
}
