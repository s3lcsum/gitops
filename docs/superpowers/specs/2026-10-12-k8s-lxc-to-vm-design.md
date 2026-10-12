# k8s control-plane LXC → QEMU on lake

**Date:** 2026-10-12
**Status:** approved (Phase A in gitops; Phase B ops)

**Scope:** New QEMU guest at `192.168.89.253` (hostname `k8s`, VMID `102`) beside existing privileged LXC CT `101` at `192.168.89.252`. Fresh kubeadm + Argo on the VM; cutover then retire the LXC. Goal: leave LXC for better guest performance (full kernel, TUN, USB, less cgroup friction).

## Context

Lake host is single-node Proxmox `lake-1` (Intel N100, `192.168.89.254`). Control plane today is privileged Debian LXC CT `101` (`terraform/proxmox/containers.tf`): 4c / 16G / 96G, USB `/dev/ttyUSB0`, bind `/mnt/nas-media`, nesting + TUN/kmsg raw conf. Many hostNetwork services and LAN clients pin to `.252` (Traefik, AdGuard, HA/MQTT, UniFi, Authentik, external-dns AdGuard URL, WAN allowlist, Synology NFS client list).

Former Portainer LXC used `.253` and is gone. That address is reused for the new QEMU. Portainer/compose/CrowdSec LAPI must not return.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Topology | Dual-run then cutover (not same-IP swap) |
| New guest IP | `192.168.89.253/24` |
| Hostname | `k8s` (SSH/DNS clash during dual-run accepted) |
| Cluster | Fresh kubeadm on VM; do not join existing cluster |
| Size | 4 vCPU / 16G / 96G `local-lvm` (match CT) |
| Dual-run headroom | Scale down LXC pods so PVE can feed QEMU |
| USB Zigbee | Stay on CT until cutover; then move passthrough to VM |
| NAS media | No LXC bind on VM; NFS mount Synology after export allows `.253` |
| VMID | `102` (`100` retired, `101` = LXC until removal) |

## Goals

- Phase A (repo): declare QEMU in `terraform/proxmox`, reassign NetBox `.253`, scrub dead AdGuard→`.253` rewrites, document cutover.
- Phase B (ops): boot VM, kubeadm + Argo, migrate data, repoint LAN/DNS/WAN, remove CT `101`.

## Non-goals

- Recreate Portainer, compose stacks, or CrowdSec LAPI.
- Join VM as second control-plane to the LXC cluster.
- Move `.252` onto the VM.
- USB passthrough to both guests at once.
- Plan/apply `terraform/postgres`.
- Automate kubeadm from OpenTofu.

## Phase A — gitops

1. `proxmox_virtual_environment_vm.k8s` + Debian 13 cloud image download + cloud-init (SSH key var).
2. NetBox: `.253` active as new k8s QEMU (replace `portainer-retired`).
3. AdGuard: delete Portainer-era rewrites still aimed at `.253` (`adminer`, `dozzle`, `ghostfolio`, `portainer`, `vaultwarden`).
4. `AGENTS.md`: dual-run note; Portainer still forbidden.

## Phase B — cutover runbook

1. Terrakube UI apply `terraform/proxmox` → VM up; SSH to `192.168.89.253`.
2. Scale down LXC workloads for host RAM (N100 + 16G QEMU while CT still runs).
3. Synology: add `192.168.89.253` to NFS export clients; mount library paths in guest (e.g. `/mnt/nas-media`).
4. Fresh `kubeadm init`; install Flannel; `make -C kubernetes/argocd bootstrap` with context aimed at the new API.
5. Data move: CNPG `pg_dump` / restore (no Barman); copy hostPath trees (`/var/lib/hass`, gitea under `/mnt/nas-media/gitea`, etc.).
6. Cutover window:
   - Move USB device passthrough from CT to VM in tofu; apply.
   - Repoint AdGuard terraform rewrites / external-dns target / LAN MQTT (`:1883`) / WAN allowlist from `.252` → `.253`.
   - Update RouterOS / NetBox / CoreDNS upstream notes as needed.
7. Stop CT `101`; remove `proxmox_virtual_environment_container.k8s` from tofu; reclaim or reserve `.252`.
8. Regenerate `.opencode/kubeconfig-k8s-lake` for the new API endpoint.

## Risks

- Dual-run OOM if LXC pods are not shed before the 16G QEMU stays up.
- Fresh cluster → cutover downtime; `local-path` CNPG is not portable without dump/restore.
- `.253` reuse without scrubbing AdGuard → dead Portainer names resolve to the new node.

## Success

- VM `102` reachable at `.253`; kubeadm control plane healthy after Phase B.
- HostNetwork edge (Traefik/AdGuard/HA) and NFS clients work on `.253`.
- CT `101` gone; Portainer still not recreated.
