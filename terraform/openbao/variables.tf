variable "vault_addr" {
  type        = string
  description = "OpenBao API address (HTTPS)."
  default     = "https://openbao.dominiksiejak.pl"
}

variable "approle_role_id" {
  type        = string
  description = "AppRole role_id for tofu (1Password openbao/approle-role-id)."
  sensitive   = true
}

variable "approle_secret_id" {
  type        = string
  description = "AppRole secret_id for tofu (1Password openbao/approle-secret-id)."
  sensitive   = true
}

variable "oidc_client_id" {
  type        = string
  description = "Authentik OpenBao OAuth client id (1Password openbao/oidc-client-id)."
  sensitive   = true
}

variable "oidc_client_secret" {
  type        = string
  description = "Authentik OpenBao OAuth client secret (1Password openbao/oidc-client-secret)."
  sensitive   = true
}
