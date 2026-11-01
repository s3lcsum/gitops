# Cloud stack resources live in sibling .tf files:
#   datasources.tf  — VictoriaMetrics + Loki via PDC
#   dashboards.tf   — JSON under dashboards/<category>/ → Monitoring/<Category> folders
#   sso.tf          — Authentik Generic OAuth
#   irm.tf          — OnCall grafana_alerting + escalation
#   alerting.tf     — critical workloads + vibe fan/ismc silence (s3lcsum)
