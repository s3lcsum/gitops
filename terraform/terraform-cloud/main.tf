# Data source for the organization
data "tfe_organization" "main" {
  name = var.organization_name
}

resource "tfe_oauth_client" "test" {
  organization     = data.tfe_organization.main.name
  api_url          = "https://api.github.com"
  http_url         = "https://github.com"
  oauth_token      = var.github_oauth_token_id
  service_provider = "github"
}

# Create all workspaces using for_each
resource "tfe_workspace" "workspaces" {
  for_each = local.workspaces

  name              = each.key
  organization      = data.tfe_organization.main.name

  tags              = {}
  queue_all_runs    = try(each.value.queue_all_runs, false)

  vcs_repo {
    identifier     = "s3lcsum/gitops"
    branch         = "main"
    oauth_token_id = var.github_oauth_token_id
  }

  auto_apply = false
  working_directory = try(each.value.working_directory, null)
}

# Configure workspace settings for local execution
resource "tfe_workspace_settings" "workspace_settings" {
  for_each = local.workspaces

  workspace_id   = tfe_workspace.workspaces[each.key].id
  execution_mode = try(each.value.execution_mode, "local")
}
