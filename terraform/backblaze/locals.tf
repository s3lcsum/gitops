locals {
  buckets = {
    "atom-1-hass-backups" = {
      description = "Home Assistant backups for atom-1"
    }
    "atom-1-proxmox-snapshots" = {
      description = "Proxmox snapshots for atom-1"
    }
    "wally-1-routeros-backups" = {
      description = "RouterOS backups for wally-1"
    }
    "wally-1-proxmox-snapshots" = {
      description = "Proxmox snapshots for wally-1"
    }
  }
}
