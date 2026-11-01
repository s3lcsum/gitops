# Non-secret defaults. Secrets: local.secret (ephemeral from OpenBao).
locals {
  cfg = {
    grafana_cloud_url    = "https://dreewniak.grafana.net"
    loki_url             = "http://loki:3100"
    oncall_url           = "https://oncall-prod-eu-west-0.grafana.net/oncall"
    oncall_username      = "dreewniak@gmail.com" # OnCall login (matches stack user, not GitHub handle)
    pdc_network_id       = "e8558cb8-eea9-4eb5-a58e-1ba9f7181431"
    victoria_metrics_url = "http://victoria-metrics:8428"
  }
}
