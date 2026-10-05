# Terrakube OpenTofu Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or implement inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Terrakube healthy, then migrate all 11 active OpenTofu modules to Terrakube workspaces with Terrakube-hosted state, VCS plan on PR, UI-only apply, and retire GHA `terraform.yml`.

**Architecture:** Wave 0 hardens the Terrakube platform in gitops. Waves 1–4 create one Terrakube workspace per `terraform/<module>`, migrate GCS state → Terrakube remote, switch backend, prove empty plan + UI apply. Drop `terraform/postgres` (CNPG owns DB).

**Tech Stack:** Terrakube chart `4.7.10` / app `2.33.1`, OpenTofu `1.12.5`, CNPG, MinIO, Authentik→Dex, Terrakube CLI/API, GitHub VCS.

**Spec:** `docs/superpowers/specs/2026-10-05-terrakube-tofu-migration-design.md`

## Global Constraints

- OpenTofu pin `1.12.5` (`terraform/.opentofu-version`)
- One org, one workspace per module dir name
- Active modules only: `adguard`, `authentik`, `backblaze`, `cloudflare`, `gcp`, `gitea`, `grafana`, `netbox`, `proxmox`, `routeros`, `unifi`
- Exclude `postgres` (CNPG)
- State → Terrakube/MinIO; no live dual GCS after cutover
- PR auto-plan; apply only from Terrakube UI
- Per-module secrets (no shared global bag)
- Retire `.github/workflows/terraform.yml` after all waves prove apply path
- Context `k8s@lake`; do not commit secrets

---

### Task 1: Wave 0 — durable Terrakube platform gitops

**Files:**
- Modify: `kubernetes/terrakube/resources/database.yaml`
- Modify: `kubernetes/terrakube/resources/externalsecret.yaml`
- Modify: `kubernetes/terrakube/values.yaml`
- Modify: `scripts/auth_classification.yaml` (add terrakube hosts if missing)

- [ ] Wire `DatabaseRole` `passwordSecret.name: terrakube-user`
- [ ] Add ExternalSecret `terrakube-user` in `cloudnative-pg` (basic-auth from 1Password `terrakube/db-password` + username `terrakube_user`) OR document that field must exist in 1Password item `terrakube`
- [ ] Fix `terrakube-api-secrets` to pull `dbPassword` from `terrakube/db-password` (same 1Password item field), not bogus `key: terrakube-user` on onepassword store
- [ ] Lengthen API startup probe / memory requests in `values.yaml` if chart supports; else document Argo ignore + patch
- [ ] Add auth classification hosts: `terrakube.dominiksiejak.pl`, `terrakube-api.dominiksiejak.pl`, `terrakube-reg.dominiksiejak.pl`
- [ ] Commit platform fixes
- [ ] Verify: Argo `terrakube` Healthy; pods Ready; UI/API 200; Dex OIDC issuer OK; Authentik healthy

### Task 2: Wave 0 — 1Password + bootstrap durability

- [ ] Ensure 1Password item `terrakube` (vault Servers, tag `ArgoCD External Secrets Operator`) has fields: `pat-secret`, `internal-secret`, `client-secret`, `valkey`, `minio-root-user`, `minio-root-password`, `db-password`
- [ ] Sync ExternalSecrets after rate-limit clears (`op` / ESO)
- [ ] Confirm CNPG role has password matching secret; `ALTER ROLE` if needed once
- [ ] Confirm NFS `/volume1/media/k8s/terrakube/minio` exists and owned by UID 1001

### Task 3: Terrakube org + admin team + VCS

- [ ] Login UI at `https://terrakube.dominiksiejak.pl` via Authentik (admin in `TERRAKUBE_ADMIN`)
- [ ] Create PAT / team token for CLI
- [ ] `terrakube login -a https://terrakube-api.dominiksiejak.pl -t "$TERRAKUBE_PAT"`
- [ ] Create organization `homelab`
- [ ] Create team `TERRAKUBE_ADMIN` with manage-* roles
- [ ] Connect GitHub VCS (PAT/App) for this repo

### Task 4: Wave 1 workspaces — netbox, gitea, backblaze, grafana

For each module:

```bash
terrakube workspace create -o "$ORG_ID" \
  --name "<module>" \
  --source "https://github.com/<owner>/<repo>" \
  --branch "main" \
  --folder "terraform/<module>" \
  --iac-type "tofu" \
  --iac-version "1.12.5" \
  --execution-mode "remote"
```

- [ ] Create four workspaces
- [ ] Load per-module secrets/vars into each workspace
- [ ] Migrate state: `cd terraform/<m> && tofu state pull > /tmp/<m>.json` then push into Terrakube remote / switch backend
- [ ] Replace GCS backend with Terrakube remote backend block
- [ ] UI/PR plan → empty or expected-only diff
- [ ] One manual UI apply
- [ ] Commit backend switch per module (or batch wave 1)

### Task 5: Wave 2 — gcp, cloudflare

- [ ] Same cutover as Task 4 for `gcp`, `cloudflare`

### Task 6: Wave 3 — authentik

- [ ] Same cutover for `authentik` (after login already proven)

### Task 7: Wave 4 — adguard, proxmox, unifi, routeros

- [ ] Same cutover for LAN modules (executor in-cluster)

### Task 8: Retire GHA + docs

**Files:**
- Delete or disable: `.github/workflows/terraform.yml`
- Modify: `AGENTS.md` (Terrakube owns plan/apply; drop GHA WireGuard CI note for tofu)
- Modify: design/plan status → done

- [ ] Remove workflow after all 11 workspaces have clean plan + proven apply
- [ ] Update AGENTS.md
- [ ] Commit

## Verification (global)

```bash
kubectl --context k8s@lake -n argocd get application terrakube
kubectl --context k8s@lake -n terrakube get pods
curl -sk https://terrakube-api.dominiksiejak.pl/actuator/health
# per module: Terrakube UI plan empty; state backend not gcs
```
