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
    "cloudflared",
    "cyberchef",
    "dozzle",
    "firefly",
    "gatus",
    "gitea",
    "grafana-synthetic-agent",
    "homarr",
    "mediabox",
    "monitoring",
    "n8n",
    "netbox",
    "omnitools",
    "postgres",
    "traefik",
    "upsnap",
    "vault",
    "vaultwarden",
    "watchtower",
    "watchyourlan",
  ]
}
