# OpenBao Secrets Platform — Design

Date: 2026-10-10
Cluster: `k8s@lake` (`192.168.89.252`)

## Goal

Stand up **OpenBao** in Kubernetes as the long-term secret store that will replace 1Password for External Secrets Operator (ESO) consumers. **Phase 1 ships the platform only.** 1Password and the existing `ClusterSecretStore/onepassword` stay live. No application ExternalSecret is flipped in this cut.

Driver: 1Password cloud SA rate limits (Families/personal caps). Homelab already mitigates with `OnChange` + hourly stagger; OpenBao removes ongoing cloud API pressure once secrets migrate later.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Product | OpenBao (Vault API-compatible fork), not HashiCorp Vault OSS |
| Consumer model | ESO only — apps keep Kubernetes Secrets; no Agent/CSI in Phase 1 |
| Unseal | Shamir keys in 1Password → ESO → Secret → unseal CronJob (not GCP KMS, not Transit) |
| Topology | Single replica, Raft integrated storage, `local-path` PVC |
| UI host | `openbao.dominiksiejak.pl`, native OIDC via Authentik |
| Cutover | Platform first; migrate ExternalSecrets in a later phase |
| Packaging | Helm chart + thin Kustomize (ApplicationSet pattern) |

Rejected: pure Kustomize manifests, bank-vaults operator, 3-node HA, NFS for Raft, revived GCP KMS auto-unseal, big-bang secret copy in Phase 1.

## Current state

- ESO chart `2.11.0` (`kubernetes/external-secrets/`), `homelab-critical`
- `ClusterSecretStore/onepassword` → vault `Servers`, `onepasswordSDK`, cache TTL `1h`
- ~26 ExternalSecrets, `refreshPolicy: OnChange` / `refreshInterval: 0s`
- CronJob `eso-stagger-refresh` force-syncs ~1 onepassword ExternalSecret per hour
- Prior HashiCorp Vault (compose + `terraform/vault` + GCP KMS) was removed; do not resurrect that module or GCS prefix as the live system
- Authentik OAuth2 apps live in `terraform/authentik/locals.tf` → `oauth2_applications`

## Architecture

```
Authentik (auth.dominiksiejak.pl)
        │ OIDC (UI/API login)
        ▼
┌─────────────────────────────────────────────┐
│  OpenBao (ns: openbao)                      │
│  Helm chart openbao/openbao                 │
│  1× Raft, local-path PVC, UI on :8200       │
│  TLS off in-pod; Traefik terminates HTTPS   │
└───────────────┬─────────────────────────────┘
                │
     ┌──────────┴──────────┐
     ▼                     ▼
ClusterSecretStore/     (future) ExternalSecrets
openbao                 store: openbao
(K8s auth, ESO SA)      — not flipped in Phase 1
     ▲
     │ still active
ClusterSecretStore/onepassword ←── all live ExternalSecrets
     ▲
1Password Servers (unseal keys + OIDC client secret only for OpenBao bootstrap)
```

## Components

### `kubernetes/openbao/` (ApplicationSet)

**Helm (`values.yaml`)**

- Chart repo: OpenBao Helm (`https://openbao.github.io/openbao-helm`), chart `openbao`
- Pin exact chart/app version at implementation time (no floating tags)
- `server.ha.enabled=true`, `server.ha.replicas=1`, `server.ha.raft.enabled=true`
- `server.dataStorage`: enabled, `local-path` (or cluster default), size 5–10Gi
- Injector / CSI / agent sidecar features: **disabled**
- `priorityClassName: homelab-critical`
- Prefer control-plane node (`k8s`); tolerate control-plane taint
- Listener TLS disabled; Traefik provides HTTPS at the edge

**Kustomize (`kustomization.yaml` + `resources/`)**

| Resource | Purpose |
|----------|---------|
| Namespace | `openbao` (if not created by chart) |
| IngressRoute | Host `openbao.dominiksiejak.pl`; middlewares `crowdsec-bouncer` + `secure-headers` in `traefik` ns; no Authentik forward-auth |
| ExternalSecret `openbao-unseal` | Shamir key shares from 1Password item `openbao` → Secret for unsealer |
| ExternalSecret `openbao-oidc` | Authentik client secret (and related fields) for OIDC auth method config / bootstrap |
| CronJob `openbao-unseal` | Poll sealed status; run `bao operator unseal` with key shares from Secret |
| ClusterSecretStore `openbao` | ESO → OpenBao over K8s auth (Ready in Phase 1; unused by app ExternalSecrets) |
| ServiceAccount `eso-openbao` | In `external-secrets` ns; ClusterSecretStore uses its JWT for OpenBao Kubernetes auth. OpenBao role bound to this SA only (not the controller SA) |

Optional Phase 1 stretch (include if cheap): Raft snapshot CronJob writing to a static NFS `nas-bind` path under an existing export. Not required for first green UI.

### Authentik (`terraform/authentik`)

- Add `openbao` to `oauth2_applications`:
  - redirect URI: `https://openbao.dominiksiejak.pl/ui/vault/auth/oidc/oidc/callback` (Vault-compatible UI path; adjust only if the pinned OpenBao version documents a different callback)
- **Admins only** — do **not** add to `user_accessible_apps`
- After apply: copy client id/secret from `tofu output` into 1Password item `openbao` (fields for OIDC)

### DNS

- `terraform/adguard`: rewrite `openbao.dominiksiejak.pl` → `192.168.89.252`
- Auth classification: `native-oidc` (restore/update `scripts/auth_classification.yaml` if that file is brought back)

### Bootstrap OpenBao config (manual / one-shot after first unseal)

Not fully GitOps-managed in Phase 1 (chicken-and-egg with seal). Operator runbook:

1. `bao operator init` once → store all Shamir shares + root token in 1Password `Servers` / `openbao`
2. Wait for ESO + unseal CronJob → unsealed
3. With root (or bootstrap token):
   - Enable KV v2 at `secret/`
   - Enable `kubernetes` auth; configure against in-cluster API
   - Policy + role for ESO SA: read on agreed KV paths (empty until migration)
   - Enable `oidc` auth; Authentik issuer `https://auth.dominiksiejak.pl/application/o/openbao/`; map Authentik `admins` group → OpenBao policy `admin` (full capability on `secret/*` + sys as needed for UI)
4. Keep root token in 1Password for break-glass; prefer OIDC for day-to-day UI

Later phases may add OpenTofu/`bao` automation for policies; out of Phase 1 scope.

## Data flows

### Unseal (steady state)

1. OpenBao pod starts sealed
2. CronJob (every 1–2 minutes) reads `/v1/sys/seal-status`
3. If sealed and Secret present → apply enough Shamir shares via `bao operator unseal`
4. Unseal Secret sourced from 1Password with `OnChange` — no periodic 1P poll for keys

### UI login

Browser → Traefik → OpenBao UI → OIDC → Authentik → back to OpenBao with admin policy.

### Secret consumption (Phase 1 = unchanged)

Apps → ExternalSecret → `ClusterSecretStore/onepassword` → 1Password. `ClusterSecretStore/openbao` exists and reports Ready but has zero consumers.

## Failure modes

| Failure | Effect | Mitigation |
|---------|--------|------------|
| OpenBao sealed/down | UI/API unavailable; app secrets still from 1P | Unseal CronJob; 1P path independent |
| Unseal Secret wrong/missing | Stays sealed | Fix 1P item / force-sync ExternalSecret |
| PVC or control-plane disk loss | Raft data lost | Optional NAS snapshots; restore + unseal |
| Authentik down | OIDC UI login fails | ESO K8s auth still works; break-glass root in 1P |
| 1P rate limit | App ExternalSecrets still staggered; unseal Secret already in-cluster | No change to stagger CronJob |

## Success criteria (Phase 1)

- `https://openbao.dominiksiejak.pl` reachable; admin OIDC login via Authentik works
- After deleting the OpenBao pod, instance returns to **initialized + unsealed** without manual unseal
- `ClusterSecretStore/openbao` is Ready
- All existing ExternalSecrets still use `onepassword`; 1P stagger CronJob still healthy
- AdGuard resolves `openbao.dominiksiejak.pl` to `192.168.89.252`

## Non-goals (Phase 1)

- Migrating any secret from 1Password into OpenBao KV
- Changing any app ExternalSecret `secretStoreRef`
- Removing or disabling `ClusterSecretStore/onepassword`
- GCP KMS / Transit auto-unseal
- Vault Agent Injector, CSI driver, or per-app Kubernetes auth roles
- 3-node Raft HA
- Recreating retired `terraform/vault` or compose Vault stack

## Follow-up (not this cut)

1. Copy selected `Servers` items into OpenBao KV
2. Flip ExternalSecrets to `ClusterSecretStore/openbao` one-by-one
3. Retire stagger CronJob pressure; eventually reduce 1P to break-glass / human password manager only
4. Optional: OpenTofu or Jobs to manage OpenBao policies/auth as code

## Repo touch list (implementation)

- `kubernetes/openbao/` (new: values + kustomize resources)
- `terraform/authentik/locals.tf` (`oauth2_applications.openbao`)
- `terraform/adguard/locals.tf` (rewrite)
- `kubernetes/external-secrets/` only if ClusterSecretStore is better owned there — prefer defining `ClusterSecretStore/openbao` under `kubernetes/openbao/` so the app owns its store
- Docs/runbook under `docs/` or comments in resources for init/unseal bootstrap
- `AGENTS.md` / `CHANGELOG.md` when implementation lands (not required for this spec commit)
