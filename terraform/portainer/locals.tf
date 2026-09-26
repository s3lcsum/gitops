# Stacks
locals {
  networks = [
    "proxy",
    "metrics",
    "database",
  ]

  stacks = [
    "dozzle",
    "postgres",
    "traefik",
  ]
}
