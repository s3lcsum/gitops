# Stacks
locals {
  networks = [
    "proxy",
    "metrics",
    "database",
  ]

  stacks = [
    "authentik",
    "beszel",
    "calibre",
    "cloudflared",
    "dozzle",
    "gatus",
    "gitea",
    "grafana-synthetic-agent",
    "hass",
    "homarr",
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
