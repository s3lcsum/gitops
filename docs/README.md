# 📚 Docs

This directory is where I keep the “why” and the “how”, not just the raw configs.

### What lives here

- **Golden paths** (`docs/golden-paths/`): the recommended way to do common changes in this repo.
- **Runbooks** (`docs/runbooks/`): incident/triage docs (“it’s on fire, now what?”).
- **Playbooks** (`docs/playbooks/`): repeatable ops tasks (“do X safely, step-by-step”).
- **ADRs** (`docs/adr/`): short decision records that explain *why* I picked approach A over B.

---

## C4 Container view

This is a C4-style “container view” of the homelab stack. It’s intentionally high level: major runtime pieces + how they talk.

```mermaid
flowchart TB
  internet[(Internet)]
  isp["ISP/FTTH"]
  router["RouterOS (MikroTik)"]
  lan["LAN/WiFi"]

  proxmox["Proxmox VE (lake-1/edge-1)"]
  lxc["LXC Containers"]
  docker["Docker Runtime"]
  portainer["Portainer"]

  traefik["Traefik (edge proxy)"]
  crowdsec["CrowdSec (security)"]
  cloudflared["Cloudflared (tunnel)"]
  wg["WireGuard"]

  apps["Stacks (Compose)"]
  postgres["PostgreSQL"]
  authentik["Authentik (IdP)"]
  netbox["NetBox (inventory/IPAM)"]
  vaultwarden["Vaultwarden"]

  terraform["Terraform modules"]

  internet --> isp --> router --> lan
  internet --> cloudflared --> traefik
  internet --> wg --> router

  lan --> traefik
  router --> proxmox
  proxmox --> lxc --> docker --> portainer
  portainer --> apps

  traefik --> crowdsec
  traefik --> apps`

  apps --> postgres
  apps --> authentik
  apps --> netbox
  apps --> vaultwarden

  terraform --> netbox
  terraform --> authentik
  terraform --> proxmox
  terraform --> router
```

---

## Conventions

- Keep docs small and useful. If it’s too long for someone to follow at 2AM, it’s probably missing a runbook/playbook split.
- Prefer links to actual repo paths (`stacks/<name>/`, `terraform/<module>/`) over copy-pasting giant configs.


