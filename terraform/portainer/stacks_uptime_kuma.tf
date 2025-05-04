resource "portainer_stack" "uptime_kuma" {
  deployment_type           = "standalone"
  method                    = "repository"
  endpoint_id               = var.endpoint_id
  repository_url            = var.default_portainer_stack_repository_url
  repository_reference_name = "refs/heads/main"

  name                    = "uptime_kuma"
  file_path_in_repository = "stacks/uptime_kuma/compose.yaml"
}
