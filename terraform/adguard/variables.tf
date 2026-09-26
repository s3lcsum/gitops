variable "adguard_host" {
  description = "AdGuard Home API host:port. Host-network HTTP on the lake node, not the Authentik-fronted name."
  type        = string
  default     = "192.168.89.252:3000"
}

variable "adguard_username" {
  description = "AdGuard Home admin user"
  type        = string
  default     = "dsiejak"
}

variable "adguard_password" {
  description = "AdGuard Home admin password (1Password). Not the bcrypt hash in AdGuardHome.yaml."
  type        = string
  sensitive   = true
}
