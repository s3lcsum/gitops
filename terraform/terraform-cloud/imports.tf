
data "tfe_workspace_ids" "all" {
  organization = var.organization_name
  names        = keys(local.workspaces)
}

import {
  for_each = data.tfe_workspace_ids.all.full_names
  to       = tfe_workspace.workspaces[each.key]
  id       = each.value
}

import {
  for_each = data.tfe_workspace_ids.all.full_names
  to       = tfe_workspace_settings.workspace_settings[each.key]
  id       = each.value
}
