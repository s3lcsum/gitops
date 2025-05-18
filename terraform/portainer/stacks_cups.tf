resource "portainer_stack" "cups" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "cups"
  stack_file_path = "../../stacks/cups/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["cups"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
