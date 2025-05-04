resource "portainer_stack" "mktxp" {
  deployment_type           = "standalone"
  method                    = "repository"
  endpoint_id               = var.endpoint_id
  repository_url            = var.default_portainer_stack_repository_url
  repository_reference_name = "refs/heads/main"

  name                    = "mktxp"
  file_path_in_repository = "stacks/mktxp/compose.yaml"
}
