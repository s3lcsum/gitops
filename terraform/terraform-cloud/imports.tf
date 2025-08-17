# Import existing Terraform Cloud workspaces
# These import blocks will import existing workspaces into Terraform state
# Using organization/workspace format for readability

import {
  to = tfe_workspace.workspaces["proxmox"]
  id = "dominiksiejak/gitops-proxmox"
}

import {
  to = tfe_workspace.workspaces["backblaze"]
  id = "dominiksiejak/gitops-backblaze"
}

import {
  to = tfe_workspace.workspaces["netbox"]
  id = "dominiksiejak/gitops-netbox"
}

import {
  to = tfe_workspace.workspaces["authentik"]
  id = "dominiksiejak/gitops-authentik"
}

import {
  to = tfe_workspace.workspaces["portainer"]
  id = "dominiksiejak/gitops-portainer"
}

import {
  to = tfe_workspace.workspaces["routeros"]
  id = "dominiksiejak/gitops-routeros"
}

import {
  to = tfe_workspace.workspaces["terraform_cloud"]
  id = "dominiksiejak/gitops-terraform-cloud"
}

import {
  to = tfe_workspace.workspaces["terraform_cloudflare"]
  id = "dominiksiejak/terraform-cloudflare"
}

import {
  to = tfe_workspace.workspaces["terraform_grafana"]
  id = "dominiksiejak/terraform-grafana"
}

# Import existing workspace settings
# Workspace settings use the same workspace ID format
import {
  to = tfe_workspace_settings.workspace_settings["proxmox"]
  id = "dominiksiejak/gitops-proxmox"
}

import {
  to = tfe_workspace_settings.workspace_settings["backblaze"]
  id = "dominiksiejak/gitops-backblaze"
}

import {
  to = tfe_workspace_settings.workspace_settings["netbox"]
  id = "dominiksiejak/gitops-netbox"
}

import {
  to = tfe_workspace_settings.workspace_settings["authentik"]
  id = "dominiksiejak/gitops-authentik"
}

import {
  to = tfe_workspace_settings.workspace_settings["portainer"]
  id = "dominiksiejak/gitops-portainer"
}

import {
  to = tfe_workspace_settings.workspace_settings["routeros"]
  id = "dominiksiejak/gitops-routeros"
}

import {
  to = tfe_workspace_settings.workspace_settings["terraform_cloud"]
  id = "dominiksiejak/gitops-terraform-cloud"
}

import {
  to = tfe_workspace_settings.workspace_settings["terraform_cloudflare"]
  id = "dominiksiejak/terraform-cloudflare"
}

import {
  to = tfe_workspace_settings.workspace_settings["terraform_grafana"]
  id = "dominiksiejak/terraform-grafana"
}
