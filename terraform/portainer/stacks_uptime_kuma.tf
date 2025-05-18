resource "portainer_stack" "uptime_kuma" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "uptime_kuma"
  stack_file_path = "../../stacks/uptime_kuma/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["uptime_kuma"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
