resource "proxmox_virtual_environment_metrics_server" "influxdb" {
  name            = "VictoriaMetrics"
  server          = var.metrics_influxdb_server
  port            = 443
  type            = "influxdb"
  influx_db_proto = "https"
}
