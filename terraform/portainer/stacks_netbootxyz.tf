resource "portainer_stack" "netbootxyz" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "netbootxyz"
  stack_file_path = "../../stacks/netbootxyz/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["netbootxyz"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
