variable "grafana_url" {
  description = "URL of the Grafana instance"
  type        = string
  default     = "https://grafana.dominiksiejak.pl"
}

variable "grafana_admin_user" {
  description = "Grafana admin username (from stacks/monitoring/grafana.env GF_SECURITY_ADMIN_USER)"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password (from stacks/monitoring/grafana.env GF_SECURITY_ADMIN_PASSWORD)"
  type        = string
  sensitive   = true
}