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
    "cloudflared",
    "gatus",
    "gitea",
    "mediabox",
    "monitoring",
    "n8n",
    "netbox",
    "postgres",
    "traefik",
    "unifi",
    "watchyourlan",
  ]
}
