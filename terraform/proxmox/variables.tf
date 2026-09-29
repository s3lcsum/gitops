variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://proxmox.dominiksiejak.pl:8006"
}

variable "proxmox_api_token_id" {
  description = "API token ID, for example root@pam!terraform"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification. LAN cert is not public."
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH user for provider operations the API cannot do (bind mounts, raw lxc lines)"
  type        = string
  default     = "root"
}

variable "proxmox_openid_client_id" {
  description = "Authentik OIDC client ID for the proxmox realm"
  type        = string
  default     = "proxmox"
}

variable "proxmox_openid_client_secret" {
  description = "Authentik OIDC client secret for the proxmox realm"
  type        = string
  sensitive   = true
}

variable "proxmox_openid_issuer_url" {
  description = "Authentik OIDC issuer URL"
  type        = string
  default     = "https://auth.dominiksiejak.pl/application/o/proxmox/"
}
