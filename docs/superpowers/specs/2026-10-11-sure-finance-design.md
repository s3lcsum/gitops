# Sure Finance — Design

Date: 2026-10-11
Cluster: `k8s@lake` (`192.168.89.252`)
Status: approved (chat)

## Goal

Deploy self-hosted [Sure](https://sure.am) (OSS personal finance, Rails + Sidekiq) on the lake cluster. Host `sure.dominiksiejak.pl`, Authentik native OIDC, no AI provider in v1.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Packaging | Kustomize-only (Netbox-shaped), not official Helm chart |
| Tree | `kubernetes/sure/` — Argo Application `application-sure.yaml` (Kustomize-only pattern) (listed in `kubernetes/argocd/resources/kustomization.yaml`) |
| Host | `sure.dominiksiejak.pl` |
| Auth class | `native-oidc` (CrowdSec + secure-headers only; no Traefik forward-auth) |
| IdP | Authentik OIDC via env `OIDC_*`; callback `/auth/openid_connect/callback` |
| AI | Off — no `OPENAI_*` |
| Postgres | Shared CNPG `Cluster/postgres`; app-owned `Database` + `DatabaseRole` |
| Redis | Per-app Valkey Deployment (same pattern as Netbox) |
| Storage | Static NFS `nas-bind` for Active Storage (`/rails/storage`) |
| Secrets | 1Password → ExternalSecret; DB role password via CNPG basic-auth + `kubernetes-cnpg` store (Terrakube pattern) |

Rejected: Helm chart (bundles CNPG/redis operators), all-in-one pod, Argo PreSync migrate Job, Pipelock, SnapTrade/Twelve keys, floating `stable` image tag.

## Architecture

```
Authentik (auth.dominiksiejak.pl)
        │ OIDC
        ▼
┌────────────────────────────────────────────────────────────┐
│  ns: sure                                                  │
│  sure-web  (Rails :3000)  ←── Traefik IngressRoute HTTPS   │
│  sure-worker (Sidekiq)                                     │
│  sure-redis (Valkey)                                       │
│  PVC sure-storage → NFS /volume1/media/k8s/sure/storage    │
└───────────────┬────────────────────┬───────────────────────┘
                │                    │
                ▼                    ▼
   postgres-rw.cloudnative-pg.svc   sure-redis:6379
   DB sure / role sure_user
```

## Components

### `kubernetes/sure/`

Application CR: `kubernetes/argocd/resources/application-sure.yaml` (must stay listed in argocd `kustomization.yaml`).

| File | Purpose |
|------|---------|
| `kustomization.yaml` | List resources |
| `resources/namespace.yaml` | `sure` |
| `resources/database.yaml` | `DatabaseRole` `sure-user` + `Database` `sure` in `cloudnative-pg` (sync-wave `-1`) |
| `resources/externalsecret.yaml` | App Secret + CNPG basic-auth Secret (wave `"-2"` before DatabaseRole; see Secrets) |
| `resources/nfs.yaml` | PV+PVC `nas-bind` → `/volume1/media/k8s/sure/storage` |
| `resources/deployment.yaml` | `sure-redis`, `sure-web`, `sure-worker`, Service `sure` |
| `resources/ingressroute.yaml` | Host match; middlewares `crowdsec-bouncer` + `secure-headers` |

**Image:** pin `ghcr.io/we-promise/sure:v0.7.5-hotfix.2` (latest non-alpha release at design time; bump intentionally later).

**Workloads**

| Deploy | priorityClass | Notes |
|--------|---------------|-------|
| `sure-redis` | `homelab-high` | Valkey (mirror Netbox pin unless newer Valkey already used elsewhere) |
| `sure-web` | `homelab-low` | Port 3000; probe `/up`; initContainer `db:prepare` |
| `sure-worker` | `homelab-low` | `bundle exec sidekiq`; shares storage PVC + env |

Control-plane toleration on all three (lake is single preferred node).

**Rails env (non-secret)**

- `SELF_HOSTED=true`
- `ONBOARDING_STATE=open` (close in UI after first admin)
- `RAILS_ASSUME_SSL=true`
- `RAILS_FORCE_SSL=false`
- `DB_HOST=postgres-rw.cloudnative-pg.svc`
- `DB_PORT=5432`
- `POSTGRES_USER=sure_user`
- `POSTGRES_DB=sure_production` (or `sure` if app accepts — confirm against image defaults at implement time; compose uses `sure_production`)
- `REDIS_URL=redis://sure-redis:6379/1`

**Migrations:** web initContainer runs `db:prepare` (wait for `pg_isready` first). Worker starts after web is Ready (or tolerates empty schema briefly; prefer `depends`-style by documenting order — no hard K8s depends_on).

### Secrets

1Password vault `Servers`, item `sure`, tag `ArgoCD External Secrets Operator`.

| Field (1Password) | Used for |
|-------------------|----------|
| `SECRET_KEY_BASE` | Rails (`openssl rand -hex 64`); **never rotate** after first boot without restore |
| `db-password` | CNPG role + app `POSTGRES_PASSWORD` |
| `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` / `OIDC_ISSUER` / `OIDC_REDIRECT_URI` | After Authentik tofu apply |

**ExternalSecrets**

1. `sure-user` → namespace `cloudnative-pg`, type `kubernetes.io/basic-auth` (`username=sure_user`, `password` from `sure/db-password`). Referenced by `DatabaseRole.spec.passwordSecret`.
2. `sure` → namespace `sure`: `SECRET_KEY_BASE`, `POSTGRES_PASSWORD` (from `kubernetes-cnpg` store key `sure-user` property `password`, or same 1Password field), OIDC keys. Template may assemble `OIDC_REDIRECT_URI=https://sure.dominiksiejak.pl/auth/openid_connect/callback` as a fixed string to avoid drift.

Do **not** put Active Record encryption keys in v1 — Sure derives from `SECRET_KEY_BASE` in self-hosted mode.

### Authentik (`terraform/authentik`)

Add `sure` to `oauth2_applications`:

- `launch_url`: `https://sure.dominiksiejak.pl`
- `redirect_uris`: `https://sure.dominiksiejak.pl/auth/openid_connect/callback`
- Icon: Sure branding URL if available; else omit / use docs favicon
- Add to `user_accessible_apps` (unlike Wealthfolio — Sure is meant as daily driver finance UI)

After apply: copy client id/secret/issuer into 1Password item `sure`.

### DNS / edge

- `terraform/adguard`: rewrite `sure.dominiksiejak.pl` → `192.168.89.252`
- Auth classification: `native-oidc` (update `scripts/auth_classification.yaml` if present)
- Homepage: tile under Data next to Wealthfolio

### Manual prerequisites (not in git)

1. Synology: create `/volume1/media/k8s/sure/storage`; ensure NFS clients include lake node IPs (`.252` / `.254` today).
2. 1Password item `sure` with generated `SECRET_KEY_BASE` + `db-password` (OIDC fields after tofu).
3. Terrakube UI apply: `terraform/authentik`, `terraform/adguard`.
4. First visit: create admin while `ONBOARDING_STATE=open`, then set onboarding Closed in Sure settings. Verify OIDC login.

## Out of scope

- Official Helm chart / CNPG or redis-operator subcharts
- OpenAI / external assistant / Pipelock
- Cloudflare Tunnel route (LAN + WireGuard + existing WAN Traefik path only)
- Retiring Wealthfolio
- Barman / ScheduledBackup for the Sure database

## Success criteria

- Application `sure` Synced/Healthy via workloads ApplicationSet
- `https://sure.dominiksiejak.pl` serves Sure behind CrowdSec + secure-headers
- Local admin + Authentik OIDC login both work
- Web and worker pods Ready; Redis Reachable; CNPG role/db exist
- Uploads persist on NFS across pod restart
