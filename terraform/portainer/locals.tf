# Stacks
locals {
  networks = [
    "proxy",
    "metrics",
    "database",
  ]

  stacks = [
    "authentik",
    "adguard",
    "calibre",
    "cloudflared",
    "dozzle",
    "gatus",
    "gitea",
    "grafana-synthetic-agent",
    "hass",
    "homepage",
    "mediabox",
    "monitoring",
    "n8n",
    "netbox",
    "postgres",
    "traefik",
    "unifi",
    "vault",
    "vaultwarden",
    "v-maintenance",
    "watchyourlan",
  ]
}
