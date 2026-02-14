variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
  sensitive   = true
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_database" {
  description = "Admin connection database (typically 'postgres')"
  type        = string
  default     = "postgres"
}

variable "postgres_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "postgres_sslmode" {
  description = "PostgreSQL SSL mode (e.g., require, verify-full)"
  type        = string
  default     = "require"
}
