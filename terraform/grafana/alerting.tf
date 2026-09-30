resource "grafana_rule_group" "blackbox_page" {
  name             = "blackbox-page-call"
  folder_uid       = grafana_folder.monitoring.uid
  interval_seconds = 60

  rule {
    name      = "Blackbox probe down (page)"
    uid       = "blackbox-probe-down-page"
    condition = "C"
    for       = "5m"

    annotations = {
      summary     = "Blackbox probe failed: {{ $labels.instance }}"
      description = "blackbox-exporter probe_success < 1 for {{ $labels.instance }} — Grafana Cloud app via IRM"
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

    # Empty query (VM restart, scrape gap) must not fan out one NoData
    # instance per stale series. Probe failure is a real 0, not missing data.
    no_data_state  = "OK"
    exec_err_state = "Error"

    # Route this rule straight to IRM. Do not rely on the root policy:
    # Grafana inserts a __grafana_receiver__ child that swallows the alert
    # before a continue=true sibling can reach the Cloud app.
    notification_settings {
      contact_point = grafana_contact_point.irm.name
      group_by      = ["grafana_folder", "alertname"]
    }
  }

  rule {
    name      = "Blackbox probe data missing (page)"
    uid       = "blackbox-probe-nodata-page"
    condition = "C"
    for       = "5m"

    annotations = {
      summary     = "Blackbox probe_success has no series"
      description = "VictoriaMetrics returned no probe_success series. Scrape gap or blackbox-exporter down — one alert, not one per target."
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
        expr          = "absent(probe_success)"
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
              type   = "gt"
              params = [0]
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
      group_by      = ["grafana_folder", "alertname"]
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
      group_by      = ["grafana_folder", "alertname"]
    }
  }
}
