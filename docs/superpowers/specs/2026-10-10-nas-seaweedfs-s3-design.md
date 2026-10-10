# NAS SeaweedFS S3 — Design

Date: 2026-10-10
Host: Synology DS223j (`nas`, `192.168.89.240`, aarch64, ~1 GiB RAM)

## Goal

NAS runs **only SeaweedFS** as the LAN object store. Expose an S3-compatible API. Remove MinIO and Garage (containers + on-disk trees). No WAN/Traefik in this cut. Terrakube rewire is out of scope (follow-up).

## Current state

| Path | Role |
|------|------|
| `/volume1/docker/minio/` | MinIO compose + data; ports `9000`/`9001` listening |
| `/volume1/docker/garage/` | Unused Garage compose stub (empty data) |
| Container Manager | Installed; docker CLI under package path; SSH user needs elevated access for daemon |

## Decision

**Single-container `weed mini`** (`chrislusf/seaweedfs`, multi-arch includes `linux/arm64`).

Why: one process (master + volume + filer + S3 + admin + maintenance), low RAM fit for DS223j, official single-node path, S3 on `:8333`.

Rejected: multi-service compose (heavier), bind S3 to `:9000` (keep Seaweed default; avoid MinIO port confusion after delete).

## Architecture

```
LAN clients (aws cli / mc / SDKs)
        │
        ▼  http://192.168.89.240:8333  (path-style S3)
┌───────────────────────────────────┐
│  Container: seaweedfs             │
│  image: chrislusf/seaweedfs       │
│  cmd: weed mini (data under /data)│
│  volumes:                         │
│    /volume1/docker/seaweedfs/data │
│    s3.json (access keys)          │
└───────────────────────────────────┘
```

- **S3 endpoint:** `http://192.168.89.240:8333` (HTTP, LAN only)
- **Admin UI / WebDAV / extra ports:** do **not** publish in v1 — only map host `8333→8333` (S3). Revisit later if needed
- **Auth:** SeaweedFS S3 config JSON with one admin identity (access key + secret). Generate on deploy; store in 1Password (item under vault `Servers`, name `seaweedfs`). Do **not** commit secrets to gitops
- **Buckets:** none at bootstrap; create later when a consumer needs them (e.g. Terrakube follow-up)


## Cleanup (destructive)

1. Stop and remove MinIO and Garage containers (if present)
2. Delete directories:
   - `/volume1/docker/minio` (includes historical `terraform` bucket data)
   - `/volume1/docker/garage`
3. No migrate — data loss accepted for this cut

## Layout on NAS

```
/volume1/docker/seaweedfs/
  compose.yaml
  config/s3.json          # identities / keys (mode 600)
  data/                   # weed data dir
```

Compose lives only on the NAS for this cut (not mirrored into gitops unless a later follow-up adds a runbook under `docs/` or `scripts/`). Optional: short ops note in this repo after deploy — not blocking.

## Ops constraints

- Prefer `sudo` / admin SSH for Container Manager docker socket
- Pin image tag to a known release (not floating `:latest`) once chosen at implement time
- Confirm `linux/arm64` pull succeeds on DS223j before wiping MinIO
- Memory: if OOM, reduce volume size limit / drop unused mini features; do not add extra containers

## Success criteria

- `curl` / `aws s3 --endpoint-url http://192.168.89.240:8333 ls` works with configured keys
- Nothing listening on MinIO `9000`/`9001` or Garage `3900–3903`
- Only SeaweedFS object-store container under `/volume1/docker/`
- MinIO and Garage trees gone

## Out of scope

- Terrakube chart: `defaultStorage: false` + external AWS endpoint
- DNS / AdGuard rewrite / Traefik IngressRoute / TLS
- Replication, erasure coding across nodes
- Migrating old MinIO objects

## Follow-up (explicit later)

Point Terrakube at `http://192.168.89.240:8333`, drop in-cluster MinIO + NFS PV, rotate 1Password keys to Seaweed credentials.
