resource "portainer_stack" "upsnap" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "upsnap"
  stack_file_path = "../../stacks/upsnap/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["upsnap"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
