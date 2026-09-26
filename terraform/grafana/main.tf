# Cloud stack resources live in sibling .tf files:
#   datasources.tf  — VictoriaMetrics via PDC
#   dashboards.tf   — JSON from kubernetes/monitoring/config/grafana-provisioning
#   sso.tf          — Authentik Generic OAuth
#   irm.tf          — OnCall integration + escalation
#   alerting.tf     — page=call synthetic probe rule
