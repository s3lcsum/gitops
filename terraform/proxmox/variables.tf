variable "virtual_environment_endpoint" {
  description = "Virtual environment endpoint"
  type        = string
  default     = "https://proxmox.lake.dominiksiejak.pl"
}

variable "virtual_environment_api_token" {
  description = "Virtual environment API token"
  type        = string
  sensitive   = true
}

variable "virtual_environment_insecure" {
  description = "Virtual environment TLS insecure"
  type        = bool
  default     = true
}

variable "virtual_environment_ssh_agent" {
  description = "Virtual environment SSH agent"
  type        = bool
  default     = true
}

variable "virtual_environment_username" {
  description = "Virtual environment username"
  type        = string
  default     = "terraform"
}
