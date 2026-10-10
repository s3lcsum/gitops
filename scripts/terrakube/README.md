# Terrakube drift enforce

Hourly **plan → apply** on all HomeLab workspaces (staggered), with Grafana OnCall alerts when drift is remediated or apply fails.

## Pieces

| Piece | Where |
|---|---|
| Template YAML | [`templates/drift-enforce.yaml`](templates/drift-enforce.yaml) |
| Bootstrap | [`apply-drift-enforce.sh`](apply-drift-enforce.sh) |
| OnCall webhook | `grafana_oncall_integration.terrakube_drift` in `terraform/grafana` |

## Secrets (1Password)

Item: **Servers / `terrakube-tofu`** (`op://Servers/terrakube-tofu`).

Fill any field still `REPLACE_ME`, then sync into Terrakube:

```bash
./scripts/terrakube/sync-vars-from-1password.sh
```

Still needs your paste (not auto-filled):

| Field | Notes |
|---|---|
| `proxmox_api_token_secret` | Proxmox API token secret for `root@pam!terraform` |
| `proxmox_openid_client_secret` | Authentik/OIDC client secret for Proxmox |
| `b2_application_key_id` / `b2_application_key` | New Backblaze keys (local tfvars is also `REPLACE_ME`) |
| `GOOGLE_CREDENTIALS` | GCP SA JSON (Terrakube ENV) |

Already filled from 1P / local tfvars: `adguard_*`, `netbox_*` (from `Servers/netbox` `TF_API_TOKEN`), `gitea_*`, `unifi_*`, `gcp_project_id`.

## Enable

1. Apply Grafana module (creates formatted_webhook integration):

   ```bash
   cd terraform/grafana && make check && tofu plan && # UI apply via Terrakube
   tofu output -raw terrakube_drift_oncall_webhook_url
   ```

2. **Secrets gate (required):** every workspace must plan cleanly before schedules matter. Verified 2026-10-10:

   | Workspace | lastJobStatus | Vars |
   |---|---|---|
   | `authentik` / `cloudflare` / `grafana` / `routeros` | completed | OK |
   | `adguard` | failed | **none** — set `adguard_password` |
   | `proxmox` | failed | **none** — set API token id/secret + `proxmox_openid_client_secret` |
   | `gcp` | failed | only `gcp_project_id` — add `GOOGLE_CREDENTIALS` ENV |
   | `backblaze` | failed | keys set but `bad_auth_token` — rotate |
   | `netbox` | failed | `Invalid v1 token` — rotate |
   | `gitea` / `unifi` | failed | vars present — re-run Plan after deps OK |

   Source values from each module’s local `defaults.auto.tfvars` / 1Password into Terrakube workspace **TERRAFORM** (and **ENV** for GCP) vars. Confirm with a manual **Plan** job per workspace.

   Until gaps are fixed, hourly `drift-enforce` will OnCall-page plan failures for those workspaces. Disable per-workspace schedule in UI or fix vars first.

3. Upsert template + global webhook var + schedules:

   ```bash
   export GRAFANA_ONCALL_WEBHOOK_URL="$(cd terraform/grafana && tofu output -raw terrakube_drift_oncall_webhook_url)"
   make -C scripts/terrakube drift-enforce
   ```

   Schedules for workspaces with broken secrets start **disabled**. Flip a row to `|1` in `apply-drift-enforce.sh` (or `ENABLE_ALL=1`) after that workspace plans clean.

## Schedule stagger

| Workspace | Cron |
|---|---|
| adguard | `0 * * * *` |
| authentik | `5 * * * *` |
| backblaze | `10 * * * *` |
| cloudflare | `15 * * * *` |
| gcp | `20 * * * *` |
| gitea | `25 * * * *` |
| grafana | `30 * * * *` |
| netbox | `35 * * * *` |
| proxmox | `40 * * * *` |
| routeros | `45 * * * *` |
| unifi | `50 * * * *` |

## Smoke test

In Terrakube UI: open a healthy workspace → run template **drift-enforce**. Empty plan → silent. Forced drift → apply + OnCall page.
