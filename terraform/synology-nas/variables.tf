variable "synology_host" {
  description = "Synology NAS hostname or IP address"
  type        = string
  sensitive   = false
}

variable "synology_username" {
  description = "Synology admin username"
  type        = string
  sensitive   = true
}

variable "synology_password" {
  description = "Synology admin password"
  type        = string
  sensitive   = true
}

variable "synology_insecure_skip_verify" {
  description = "Skip SSL certificate verification"
  type        = bool
  default     = false
  sensitive   = false
}

variable "synology_session_timeout" {
  description = "Session timeout in seconds"
  type        = number
  default     = 1800
  sensitive   = false
}
