variable "vault_address" {
  description = "Vault server address"
  type        = string
  default     = "https://vault.lake.dominiksiejak.pl"
}

variable "vault_token" {
  description = "Vault root token for initial configuration"
  type        = string
  sensitive   = true
}

# =============================================================================
# PostgreSQL
# =============================================================================

variable "postgres_admin_user" {
  description = "PostgreSQL admin user for Vault database secrets engine"
  type        = string
  default     = "postgres"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password for Vault database secrets engine"
  type        = string
  sensitive   = true
}

# =============================================================================
# Audit Devices
# =============================================================================

variable "vault_audit_enabled" {
  description = "Whether to configure a Vault audit device"
  type        = bool
  default     = false
}

variable "vault_audit_file_path" {
  description = "Audit log file path. Use 'stdout' for container-friendly logging."
  type        = string
  default     = "stdout"
}
