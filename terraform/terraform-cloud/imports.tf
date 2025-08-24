import {
  for_each = local.workspaces
  to       = tfe_workspace.workspaces[each.key]
  id       = "dominiksiejak/${each.value.name}"
}

import {
  for_each = local.workspaces
  to       = tfe_workspace_settings.workspace_settings[each.key]
  id       = "dominiksiejak/${each.value.name}"
}
