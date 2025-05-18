resource "portainer_stack" "authentik" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "authentik"
  stack_file_path = "../../stacks/authentik/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["authentik"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
