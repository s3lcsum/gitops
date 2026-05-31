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
    "gitea",
    "grafana-synthetic-agent",
    "hass",
    "mediabox",
    "monitoring",
    "n8n",
    "netbox",
    "postgres",
    "traefik",
    "upsnap",
    "vault",
    "unifi",
    "vaultwarden",
    "watchyourlan",
  ]
}
