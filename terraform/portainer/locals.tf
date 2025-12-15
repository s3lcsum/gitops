# Stacks
locals {
  networks = [
    "proxy",
    "metrics",
    "database",
  ]

  stacks = [
    "adguard",
    "authentik",
    # "calibre",
    "cloudflared",
    "cups",
    "dozzle",
    "diun",
    "grafana-synthetic-agent",
    "mediabox",
    "n8n",
    "netbootxyz",
    "netbox",
    "postgres",
    "traefik",
    "upsnap",
    "uptime_kuma",
    "vault",
    "vaultwarden",
    "warrtracker",
    "watchyourlan",
  ]
}
