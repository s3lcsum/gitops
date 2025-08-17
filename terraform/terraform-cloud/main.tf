# Data source for the organization
data "tfe_organization" "main" {
  name = var.organization_name
}

# Create all workspaces using for_each
resource "tfe_workspace" "workspaces" {
  for_each = local.workspaces

  name         = each.value.name
  organization = data.tfe_organization.main.name
  description  = try(each.value.description, "Managed by Terraform")

  working_directory = try(each.value.working_directory, null)

  vcs_repo {
    identifier     = each.value.vcs_repo
    oauth_token_id = var.github_oauth_token_id
  }

  auto_apply = false
}

# Configure workspace settings for local execution
resource "tfe_workspace_settings" "workspace_settings" {
  for_each = local.workspaces

  workspace_id   = tfe_workspace.workspaces[each.key].id
  execution_mode = try(each.value.execution_mode, "local")
}
