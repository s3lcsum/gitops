resource "portainer_stack" "mktxp" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "mktxp"
  stack_file_path = "../../stacks/mktxp/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["mktxp"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
