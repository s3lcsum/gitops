resource "portainer_settings" "default" {
  authentication_method = 3
  enable_telemetry      = true

  dynamic "oauth_settings" {
    for_each = var.portainer_oauth2_enabled ? [1] : []
    content {
      access_token_uri        = var.portainer_oauth2_access_token_uri
      authorization_uri       = var.portainer_oauth2_authorization_uri
      client_id               = var.portainer_oauth2_client_id
      client_secret           = var.portainer_oauth2_client_secret
      logout_uri              = var.portainer_oauth2_logout_uri
      redirect_uri            = var.portainer_oauth2_redirect_uri
      oauth_auto_create_users = true
    }
  }
}

resource "portainer_docker_network" "networks" {
  for_each = toset(local.networks)

  name        = each.key
  endpoint_id = var.endpoint_id
  driver      = "bridge"
}

# This is always been created along with portainer.service
import {
  to = portainer_docker_network.networks["proxy"]
  id = "${var.endpoint_id}:proxy"
}

resource "portainer_stack" "stacks" {
  for_each = toset(local.stacks)

  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.endpoint_id
  name            = each.value
  pull_image      = false
  prune           = false

  stack_file_content = file("../../stacks/${each.value}/compose.yaml")

  depends_on = [portainer_docker_network.networks]
}
