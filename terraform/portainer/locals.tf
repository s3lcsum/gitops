# Stacks
locals {
  networks = [
    "proxy",
    "metrics",
    "database",
  ]

  stacks = [
    "adguard",
    # "calibre",
    "cloudflared",
    "cups",
    "dozzle",
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
    "watchtower",
    "watchyourlan",
    "zitadel",
  ]
}
