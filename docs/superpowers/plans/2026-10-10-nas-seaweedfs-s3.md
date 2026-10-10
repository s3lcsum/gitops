# NAS SeaweedFS S3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or implement task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On Synology NAS, remove MinIO + Garage and run single-container SeaweedFS (`weed mini`) exposing S3 on `:8333`.

**Architecture:** Container Manager docker; data under `/volume1/docker/seaweedfs`; only host port `8333`; S3 keys in `config/s3.json` (not git).

**Tech Stack:** Synology Container Manager, `chrislusf/seaweedfs` (arm64), SeaweedFS `weed mini` + s3.json

## Global Constraints

- Host: `192.168.89.240` (`nas`), DS223j aarch64, ~1 GiB RAM
- Publish only `8333:8333`
- Destructive delete of `/volume1/docker/minio` and `/volume1/docker/garage`
- No Terrakube changes in this plan
- Secrets never committed to gitops

---

### Task 1: Docker access + pull image

**Files:** NAS only

- [ ] Confirm docker path + sudo/socket access for SSH user
- [ ] Pull `chrislusf/seaweedfs` (pin tag after inspect; prefer recent stable)
- [ ] Verify `linux/arm64` image runs `weed version`

### Task 2: Layout + credentials

**Files:** `/volume1/docker/seaweedfs/{compose.yaml,config/s3.json,data/}`

- [ ] Create dirs
- [ ] Generate access/secret keys; write `s3.json` mode 600
- [ ] Write compose: image pin, `mini -dir=/data -s3.config=...`, volume mounts, port 8333 only, restart unless-stopped

### Task 3: Tear down MinIO + Garage

- [ ] Stop/remove minio + garage containers
- [ ] Confirm ports 9000/9001/3900–3903 free
- [ ] `rm -rf` minio + garage trees under `/volume1/docker`

### Task 4: Start SeaweedFS + verify S3

- [ ] `docker compose up -d`
- [ ] `aws s3` or `curl` list buckets with keys against `http://192.168.89.240:8333`
- [ ] Print keys once for operator → 1Password item `Servers`/`seaweedfs`
- [ ] Confirm only seaweedfs under `/volume1/docker/` object-store dirs

---
