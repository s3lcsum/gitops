resource "grafana_rule_group" "synthetic_page" {
  name             = "synthetic-page-call"
  folder_uid       = grafana_folder.monitoring.uid
  interval_seconds = 60

  rule {
    name      = "Synthetic service down (page)"
    uid       = "synthetic-service-down-page"
    condition = "C"
    for       = "5m"

    annotations = {
      summary     = "Service {{ $labels.instance }} unreachable"
      description = "Synthetic probe failed for instance {{ $labels.instance }} — Grafana Cloud app via IRM"
    }

    labels = {
      severity = "warning"
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
        expr          = "min(probe_success{instance!~\"https://(portainer|adminer|readarr|status|dozzle|opencode)\\\\.dominiksiejak\\\\.pl\"}) by (instance)"
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

    # Route this rule straight to IRM. Do not rely on the root policy:
    # Grafana inserts a __grafana_receiver__ child that swallows the alert
    # before a continue=true sibling can reach the Cloud app.
    notification_settings {
      contact_point = grafana_contact_point.irm.name
      group_by      = ["grafana_folder", "alertname", "instance"]
    }
  }
}

resource "grafana_rule_group" "homelab_incident" {
  name             = "homelab-incident"
  folder_uid       = grafana_folder.monitoring.uid
  interval_seconds = 60

  rule {
    name      = "dominiksiejak.pl down 60m"
    uid       = "dominiksiejak-down-incident"
    condition = "C"
    for       = "1h"

    annotations = {
      summary     = "{{ $labels.instance }} down for 60 minutes"
      description = "Blackbox probe_success=0 for a dominiksiejak.pl host for 60 minutes. Grafana Cloud app via IRM."
    }

    labels = {
      severity = "critical"
      incident = "true"
    }

    data {
      ref_id = "A"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = grafana_data_source.victoria_metrics.uid
      model = jsonencode({
        expr          = "min by (instance) (probe_success{instance=~\".*dominiksiejak\\\\.pl.*\",instance!~\"https://(portainer|adminer|readarr|status|dozzle|opencode)\\\\.dominiksiejak\\\\.pl\"})"
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

    no_data_state  = "OK"
    exec_err_state = "Error"

    notification_settings {
      contact_point = grafana_contact_point.irm.name
      group_by      = ["grafana_folder", "alertname", "instance"]
    }
  }
}
