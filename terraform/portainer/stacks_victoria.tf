resource "portainer_stack" "victoria" {
  deployment_type           = "standalone"
  method                    = "repository"
  endpoint_id               = var.endpoint_id
  repository_url            = var.default_portainer_stack_repository_url
  repository_reference_name = "refs/heads/main"

  name                    = "victoria"
  file_path_in_repository = "stacks/victoria/compose.yaml"

  dynamic "env" {
    for_each = try(var.portainer_stacks_envs["victoria"], {})
    content {
      name  = env.key
      value = env.value
    }
  }
}
