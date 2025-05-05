resource "portainer_stack" "nginx_proxy_manager" {
  deployment_type           = "standalone"
  method                    = "repository"
  endpoint_id               = var.endpoint_id
  repository_url            = var.default_portainer_stack_repository_url
  repository_reference_name = "refs/heads/main"

  name                    = "nginx_proxy_manager"
  file_path_in_repository = "stacks/nginx_proxy_manager/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["nginx_proxy_manager"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
