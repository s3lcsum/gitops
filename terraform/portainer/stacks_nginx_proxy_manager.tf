resource "portainer_stack" "nginx_proxy_manager" {
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = var.endpoint_id

  name            = "nginx_proxy_manager"
  stack_file_path = "../../stacks/nginx_proxy_manager/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["nginx_proxy_manager"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
