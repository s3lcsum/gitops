locals {
  # Common shared folders for a homelab setup
  shared_folders = {
    "docker" = {
      description = "Docker container data and volumes"
      path        = "/volume1/docker"
    }
    "backups" = {
      description = "System and application backups"
      path        = "/volume1/backups"
    }
    "media" = {
      description = "Media files (photos, videos, music)"
      path        = "/volume1/media"
    }
    "documents" = {
      description = "Shared documents and files"
      path        = "/volume1/documents"
    }
    "homes" = {
      description = "User home directories"
      path        = "/volume1/homes"
    }
  }

  # Common user accounts
  users = {
    "admin" = {
      description = "System administrator"
      password    = "" # Should be set via variable or external source
      groups      = ["administrators"]
    }
    "docker" = {
      description = "Docker service user"
      password    = "" # Should be set via variable or external source
      groups      = ["docker"]
    }
  }

  # Common user groups
  groups = {
    "administrators" = {
      description = "System administrators"
    }
    "docker" = {
      description = "Docker users"
    }
    "media" = {
      description = "Media access users"
    }
  }

  # API endpoints for Synology DSM
  api_endpoints = {
    auth   = "/webapi/auth.cgi"
    file   = "/webapi/entry.cgi"
    user   = "/webapi/entry.cgi"
    share  = "/webapi/entry.cgi"
    system = "/webapi/entry.cgi"
  }
}
