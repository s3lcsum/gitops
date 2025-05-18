resource "portainer_stack" "dozzle" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "dozzle"
  stack_file_path = "../../stacks/dozzle/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["dozzle"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
