# ESO cutover: 1Password → OpenBao — 2026-10-31

## Goal

Move application ExternalSecrets from `ClusterSecretStore/onepassword` to `ClusterSecretStore/openbao`. 1Password remains only for OpenBao chicken-egg and the 1Password store bootstrap token.

## Non-goals

- Deleting 1Password items (keep as offline backup until soak complete).
- Moving `secret/terraform_env/*` (already OpenBao; tofu ephemeral path).
- Changing CNPG `ClusterSecretStore/kubernetes-cnpg` (in-cluster Secret copy).
- Putting OpenBao unseal shares or the 1Password SA credential inside OpenBao.

## Stay on 1Password

| ExternalSecret | Namespace | Why |
|---|---|---|
| `openbao-unseal` | `openbao` | Cannot unseal OpenBao with secrets that require OpenBao |
| `openbao-oidc` | `openbao` | Same chicken-egg while sealed / auth cold |
| `onepassword` | `external-secrets` | Bootstraps `ClusterSecretStore/onepassword` itself |

`ClusterSecretStore/onepassword` remains Ready for those three only.

## KV layout

- Mount: `secret/` (KV v2), already granted to policy `eso-read`.
- Path: `k8s/<item>` where `<item>` is the former 1Password item name.
- Keys: same field labels as today (e.g. `OIDC_CLIENT_ID`, `dns-token`).

Examples:

| Former 1P `remoteRef.key` | OpenBao |
|---|---|
| `sure/OIDC_CLIENT_ID` | path `k8s/sure`, property `OIDC_CLIENT_ID` |
| `argocd/oidc-client-secret` | path `k8s/argocd`, property `oidc-client-secret` |
| `cloudflare/dns-token` | path `k8s/cloudflare`, property `dns-token` |
| `hass/mosquitto-passwd` | path `k8s/hass`, property `mosquitto-passwd` |

Shared 1P items (e.g. `cloudflare` used by cert-manager + external-dns) → one KV path, multiple ExternalSecrets.

Prefix `k8s/` keeps app secrets distinct from `terraform_env/<module>`.

## ExternalSecret YAML shape

```yaml
secretStoreRef:
  name: openbao
  kind: ClusterSecretStore
data:
  - secretKey: OIDC_CLIENT_ID   # k8s Secret key (unchanged)
    remoteRef:
      key: k8s/sure             # OpenBao path under mount secret/
      property: OIDC_CLIENT_ID  # map key inside that path
```

Target Secret names, templates, `creationPolicy`, `deletionPolicy`, sync-waves unchanged.

## Flip inventory

All current `secretStoreRef.name: onepassword` consumers **except** the three stay-on-1P rows above.

| ExternalSecret | Namespace | 1P item(s) → `k8s/<item>` |
|---|---|---|
| `argocd-oidc` | `argocd` | `argocd` |
| `argocd-repo-creds-github` | `argocd` | `argocd` |
| `sure` | `sure` | `sure` |
| `sure-user` | `cloudnative-pg` | `sure` |
| `cloudflared` | `cloudflared` | `cloudflare` |
| `cloudflare-api-token` | `external-dns` | `cloudflare` |
| `adguard` | `external-dns` | `adguard` |
| `crowdsec-lapi` | `traefik` | `crowdsec-lapi` |
| `cloudflare-api-token` | `cert-manager` | `cloudflare` |
| `grafana-synthetic-agent` | `grafana-synthetic-agent` | `grafana` |
| `homepage` | `homepage` | `homepage` |
| `wealthfolio` | `wealthfolio` | `wealthfolio` |
| `netbox` | `netbox` | `netbox` |
| `netbox-user` | `cloudnative-pg` | `netbox` |
| `hass-mosquitto` / `hass-mqtt` / `hass-timemachine` | `hass` | `hass` |
| `jellyfin-sso` | `mediabox` | `jellyfin` |
| `authentik-ldap-outpost` | `authentik` | `authentik` |
| `authentik-radius-outpost` | `authentik` | `authentik` |
| `mktxp` | `monitoring` | `mktxp` |
| `gluetun` | `mediabox` | `gluetun` |

Exact field lists stay as in each YAML `remoteRef.key` suffix after `/`.

## Data migration

1. Confirm `ClusterSecretStore/openbao` Ready and `eso-openbao` can read (probe path).
2. One-shot copy: 1Password vault `Servers`, items tagged for ESO → `bao kv put secret/k8s/<item> key=value …` (or HTTP KV write). Prefer AppRole / root break-glass with write on `secret/data/k8s/*` (eso-read is read-only; use terraform AppRole or root for upload).
3. Spot-check: for each path, `bao kv get secret/k8s/<item>` shows expected keys.
4. Optional: temporary test ExternalSecret in a throwaway ns before mass flip.

Do **not** copy items `openbao` unseal/oidc fields or `k8s-external-secrets` into `k8s/` for ESO consumption (those stay 1P-backed).

## Git / platform follow-ups

1. Rewrite every flip-list ExternalSecret: store → `openbao`, split `key` / `property`.
2. Update comments that say “1Password vault Servers”.
3. Narrow `eso-stagger-refresh` CronJob to only ExternalSecrets still on `onepassword` (three chicken-egg objects). Or leave filter as-is (still only force-syncs `onepassword` store refs — after flip it naturally shrinks).
4. `AGENTS.md`: app secrets from OpenBao `secret/k8s/<item>` via ESO; 1P = OpenBao unseal/OIDC + ESO 1P token only.
5. After soak (suggested ≥7 days): stop relying on 1P for flipped items; items may remain as cold backup.

## Auth / policy

- Existing: `ClusterSecretStore/openbao` → K8s auth role `eso-openbao` → policy `eso-read` (`secret/data/*`, `secret/metadata/*`).
- No policy change required for read path under `k8s/`.
- Upload needs a writer (terraform AppRole or root); not ESO.

## Rollback

1. Revert ExternalSecret YAML to `onepassword` + old `item/field` keys (git revert).
2. 1P items still present → ESO syncs again.
3. OpenBao `k8s/*` paths can remain unused.

## Success criteria

- Every flipped ExternalSecret `SecretSynced` / Ready against `openbao`.
- Workloads still get correct env (Sure OIDC, Argo CD OIDC, cloudflared tunnel, etc.).
- Only three ExternalSecrets still reference `onepassword`.
- OpenBao seal/unseal CronJob still works from 1P-backed `openbao-unseal`.

## Risks

| Risk | Mitigation |
|---|---|
| Field name mismatch on copy | Diff 1P field labels vs YAML suffixes before put |
| ESO Vault `property` missing → sync error | Upload complete maps; force-sync and watch events |
| Accidental flip of unseal ES | Explicit allowlist; PR review checklist |
| Writer credentials leak | One-shot local script; no commit of values |
