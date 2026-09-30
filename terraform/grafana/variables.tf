variable "grafana_cloud_url" {
  description = "Grafana Cloud stack URL (e.g. https://dreewniak.grafana.net)"
  type        = string
  default     = "https://dreewniak.grafana.net"
}

variable "grafana_cloud_auth" {
  description = "Grafana Cloud service account token (Admin). Needs datasources, folders, dashboards, alerting, SSO, OnCall."
  type        = string
  sensitive   = true
}

variable "pdc_network_id" {
  description = "Grafana Cloud Private Data source Connect network ID (HomeLab)"
  type        = string
  default     = "e8558cb8-eea9-4eb5-a58e-1ba9f7181431"
}

variable "victoria_metrics_url" {
  description = "VictoriaMetrics URL reachable from the PDC agent (cluster DNS or short Service name)"
  type        = string
  # Short name matches the UI-created connector; agent runs in monitoring ns.
  default = "http://victoria-metrics:8428"
}

variable "oncall_username" {
  description = "Grafana OnCall / Cloud username to page for important alerts"
  type        = string
  default     = "s3lcsum"
}

variable "oncall_url" {
  description = "Grafana Cloud OnCall API. Provider default is us-central-0; this stack is eu-west-0."
  type        = string
  default     = "https://oncall-prod-eu-west-0.grafana.net/oncall"
}

variable "oncall_access_token" {
  description = "OnCall API token from Alerts & IRM → Settings. Not a glsa_ service account token."
  type        = string
  sensitive   = true
}
