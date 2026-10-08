# Cloud stack resources live in sibling .tf files:
#   datasources.tf  — VictoriaMetrics via PDC
#   dashboards.tf   — JSON from terraform/grafana/dashboards
#   sso.tf          — Authentik Generic OAuth
#   irm.tf          — OnCall grafana_alerting integration + escalation
#   alerting.tf     — critical workload pod-down (15m) via s3lcsum
