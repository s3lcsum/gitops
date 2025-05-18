resource "portainer_stack" "watchtower" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "watchtower"
  stack_file_path = "../../stacks/watchtower/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["watchtower"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
