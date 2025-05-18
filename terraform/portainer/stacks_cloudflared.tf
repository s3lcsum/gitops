resource "portainer_stack" "cloudflared" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "cloudflared"
  stack_file_path = "../../stacks/cloudflared/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["cloudflared"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
