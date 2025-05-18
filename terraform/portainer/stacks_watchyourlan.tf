resource "portainer_stack" "watchyourlan" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "watchyourlan"
  stack_file_path = "../../stacks/watchyourlan/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["watchyourlan"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
