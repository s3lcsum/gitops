# Stacks
locals {
  networks = [
    "proxy",
    "metrics",
    "database",
  ]

  stacks = [
    "alloy",
    "authentik",
    "cloudflared",
    "cups",
    "dozzle",
    "grafana-synthetic-agent",
    "mediabox",
    "netbootxyz",
    "n8n",
    "postgres",
    "upsnap",
    "uptime_kuma",
    "traefik",
    "watchyourlan",
    "zitadel",
  ]
}
