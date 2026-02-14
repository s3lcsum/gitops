# Manage all workspaces (both existing and new)
resource "tfe_workspace" "workspaces" {
  for_each = local.workspaces

  name         = each.key
  organization = var.organization_name

  working_directory = try(each.value.working_directory, "")
  terraform_version = try(each.value.terraform_version, ">= 1.14.0")

  allow_destroy_plan            = try(each.value.allow_destroy_plan, true)
  file_triggers_enabled         = try(each.value.file_triggers_enabled, true)
  queue_all_runs                = try(each.value.queue_all_runs, false)
  speculative_enabled           = try(each.value.speculative_enabled, true)
  structured_run_output_enabled = try(each.value.structured_run_output_enabled, true)

  trigger_prefixes = try([each.value.working_directory], [])

  dynamic "vcs_repo" {
    for_each = try(each.value.vcs_repo, null) != null ? [1] : []
    content {
      identifier                 = try(each.value.vcs_repo.identifier, "")
      branch                     = try(each.value.vcs_repo.branch, "main")
      github_app_installation_id = var.github_app_installation_id
    }
  }
}

# Configure workspace settings for local execution
resource "tfe_workspace_settings" "workspace_settings" {
  for_each = local.workspaces

  description               = try(each.value.description, "")
  auto_apply                = try(each.value.auto_apply, true)
  effective_tags            = try(each.value.effective_tags, {})
  workspace_id              = tfe_workspace.workspaces[each.key].id
  execution_mode            = try(each.value.execution_mode, "local")
  global_remote_state       = try(each.value.global_remote_state, false)
  remote_state_consumer_ids = [for workspace in try(each.value.shared_with_workspaces, []) : tfe_workspace.workspaces[workspace].id]
}
