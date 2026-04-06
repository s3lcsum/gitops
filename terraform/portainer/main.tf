# Portainer settings - OAuth enabled only when authentik workspace exists
resource "portainer_settings" "default" {
  authentication_method = var.enable_oauth ? 3 : 1 # 3=OAuth, 1=Internal
  enable_telemetry      = true

  dynamic "oauth_settings" {
    for_each = var.enable_oauth ? [1] : []
    content {
      sso                     = true
      client_id               = data.terraform_remote_state.authentik[0].outputs.applications.portainer.client_id
      client_secret           = data.terraform_remote_state.authentik[0].outputs.applications.portainer.client_secret
      access_token_uri        = data.terraform_remote_state.authentik[0].outputs.applications.portainer.access_token_uri
      authorization_uri       = data.terraform_remote_state.authentik[0].outputs.applications.portainer.authorization_uri
      logout_uri              = data.terraform_remote_state.authentik[0].outputs.applications.portainer.logout_uri
      redirect_uri            = data.terraform_remote_state.authentik[0].outputs.applications.portainer.redirect_uri
      resource_uri            = data.terraform_remote_state.authentik[0].outputs.applications.portainer.resource_uri
      user_identifier         = "email"
      scopes                  = "openid profile email"
      oauth_auto_create_users = true
    }
  }
}

resource "portainer_docker_network" "networks" {
  for_each = toset(local.networks)

  name        = each.key
  endpoint_id = var.endpoint_id
  driver      = "bridge"

  enable_ipv4 = true
}

# This is always been created along with portainer.service
import {
  for_each = toset(local.networks)
  to       = portainer_docker_network.networks[each.value]
  id       = "${var.endpoint_id}:${each.value}"
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
