resource "portainer_stack" "victoria" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "victoria"
  stack_file_path = "../../stacks/victoria/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["victoria"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
