# Grafana Terraform Module Design

## Purpose

Manage Grafana runtime configuration — folders, dashboards, alerting, service accounts, users — via OpenTofu for the instance at `grafana.dominiksiejak.pl`. Infrastructure (Grafana container, OAuth, datasource provisioning) stays in Docker Compose and YAML files.

## Scope (Phase 1)

### In scope — managed by Terraform

| Resource | Terraform Resource | Source |
|---|---|---|
| Folders | `grafana_folder` | Hardcoded in `locals.tf` |
| Dashboards | `grafana_dashboard` | Imported from grafana.com via `gnetId` |
| Alert contact points | `grafana_contact_point` | Defined in `locals.tf` |
| Notification policies | `grafana_notification_policy` | Defined in `locals.tf` |
| Alert rule groups | `grafana_rule_group` | PromQL rules in `locals.tf` |
| Message templates | `grafana_message_template` | Custom templates in `locals.tf` |
| Service accounts | `grafana_service_account` | For external tool API access |
| Users | `grafana_user` | Local Grafana users (non-OIDC) |
| Teams | `grafana_team` | User grouping |

### Out of scope — stays in Docker Compose / provisioning

- Grafana container image and version
- OAuth via Authentik (`GF_AUTH_GENERIC_OAUTH_*` env vars)
- VictoriaMetrics datasource (provisioning YAML at `stacks/monitoring/grafana/provisioning/datasources/victoria-metrics.yaml`)
- Plugin installation (`GF_INSTALL_PLUGINS`)
- Grafana server config (`GF_SERVER_*`, `GF_SECURITY_*`)
- Grafana container itself (networks, volumes, labels, Traefik routing)

## Authentication

Grafana provider authenticates via admin credentials:

1. `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD` stored in Vault KV at `kv/grafana/admin`
2. `data.vault_kv_secret_v2` reads them at plan/apply time
3. User supplies `TF_VAR_vault_token` to authenticate to Vault

## Dashboards (via gnetId)

| Service | gnetId | Name | Requires |
|---|---|---|---|
| Node Exporter | 1860 | Node Exporter Full | node_exporter:9100 on vibe/lake/nas/micrus |
| Kubernetes | 15760+ | dotdc K8s Views (Global, Namespaces, Nodes, Pods) | kube-state-metrics + cAdvisor |
| Traefik | 17346 | Traefik Official Standalone | `traefik:9100` already scraped ✓ |
| Gatus | 24379 | Gatus | `gatus:8080` already scraped ✓ |
| Cloudflare | 13133 | CloudFlare Zone Analytics | lablabs/cloudflare-exporter worker |
| Docker | 15798 | Docker Monitoring (cAdvisor) | cAdvisor scraped by VictoriaMetrics |
| Portainer | — | Custom / Portainer API metrics | Portainer metrics endpoint |

## File Structure

```
terraform/grafana/
├── providers.tf       # cloud {}, grafana/grafana, hashicorp/vault
├── variables.tf       # grafana_url, vault_token, etc.
├── locals.tf          # folders, dashboard gnetIds, alert configs
├── data.tf            # vault_kv_secret_v2 for admin creds
├── main.tf            # all resources
├── outputs.tf         # service account keys
└── Makefile           # include ../base.Makefile
```

No `dashboards/` directory — all dashboards are fetched from grafana.com via `gnetId` at apply time.

## Architecture

```
User (TF_VAR_vault_token)
  │
  ▼
Vault provider ──► data.vault_kv_secret_v2 ──► admin_user + admin_password
  │
  ▼
Grafana provider (url=https://grafana.dominiksiejak.pl, auth=basic)
  │
  ├── grafana_folder (infra, k8s, services, alerting)
  ├── grafana_dashboard (via gnetId, assigned to folders)
  ├── grafana_contact_point (slack, email, webhook)
  ├── grafana_notification_policy (route by severity/tag)
  ├── grafana_rule_group (PromQL alert rules)
  ├── grafana_service_account (external tools)
  └── grafana_user (local accounts)
```

## State

- Backend: Terraform Cloud (`cloud {}`), workspace `gitops-grafana`
- Consistent with all existing modules in this repo
