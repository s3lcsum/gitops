resource "grafana_rule_group" "homelab_critical_workloads" {
  name             = "homelab-critical-workloads"
  folder_uid       = grafana_folder.monitoring.uid
  interval_seconds = 60

  rule {
    name      = "Critical workload down 15m"
    uid       = "critical-workloads-down-15m"
    condition = "C"
    for       = "15m"

    annotations = {
      summary     = "{{ $labels.namespace }} critical workload not running"
      description = "hass, mosquitto, authentik-server/worker available replicas < 1, or postgres-* not Running, for 15 minutes."
    }

    labels = {
      severity = "critical"
      page     = "call"
    }

    data {
      ref_id = "A"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = grafana_data_source.victoria_metrics.uid
      model = jsonencode({
        expr          = "(kube_deployment_status_replicas_available{namespace=~\"hass|authentik\",deployment=~\"hass|mosquitto|authentik-server|authentik-worker\"}) or (kube_pod_status_phase{namespace=\"cloudnative-pg\",pod=~\"postgres-[0-9]+\",phase=\"Running\"})"
        instant       = true
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "C"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        expression = "A"
        conditions = [
          {
            evaluator = {
              type   = "lt"
              params = [1]
            }
            operator = {
              type = "and"
            }
            query = {
              params = ["C"]
            }
            reducer = {
              type   = "last"
              params = []
            }
            type = "query"
          }
        ]
        datasource = {
          type = "__expr__"
          uid  = "__expr__"
        }
        refId = "C"
      })
    }

    no_data_state  = "Alerting"
    exec_err_state = "Error"

    notification_settings {
      contact_point = "s3lcsum"
      group_by      = ["grafana_folder", "alertname"]
    }
  }
}
