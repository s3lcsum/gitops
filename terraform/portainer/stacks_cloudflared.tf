resource "portainer_stack" "cloudflared" {
  deployment_type           = "standalone"
  method                    = "repository"
  endpoint_id               = var.endpoint_id
  repository_url            = var.default_portainer_stack_repository_url
  repository_reference_name = "refs/heads/main"
  update_interval           = "5m"

  name                    = "cloudflared"
  file_path_in_repository = "stacks/cloudflared/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["cloudflared"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
