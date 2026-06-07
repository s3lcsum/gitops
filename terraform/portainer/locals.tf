# Stacks
locals {
  networks = [
    "proxy",
    "metrics",
    "database",
  ]

  stacks = [
    "authentik",
    "calibre",
    "cloudflared",
    "dozzle",
    "gatus",
    "grafana-synthetic-agent",
    "hass",
    "mediabox",
    "monitoring",
    "n8n",
    "netbox",
    "postgres",
    "traefik",
    "unifi",
    "upsnap",
    "vault",
    "vaultwarden",
    "watchyourlan",
  ]
}
