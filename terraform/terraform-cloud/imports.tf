import {
  for_each = local.workspaces
  to       = tfe_workspace.workspaces[each.key]
  id       = "dominiksiejak/${each.key}"
}

import {
  for_each = local.workspaces
  to       = tfe_workspace_settings.workspace_settings[each.key]
  id       = "dominiksiejak/${each.key}"
}
