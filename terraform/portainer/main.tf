# Portainer settings - OAuth enabled only when authentik workspace exists
resource "portainer_settings" "default" {
  authentication_method = var.enable_oauth ? 3 : 1 # 3=OAuth, 1=Internal
  enable_telemetry      = true

  dynamic "oauth_settings" {
    for_each = var.enable_oauth ? [1] : []
    content {
      sso                             = true
      client_id                       = data.tfe_outputs.authentik[0].values.applications.portainer.client_id
      client_secret                   = data.tfe_outputs.authentik[0].values.applications.portainer.client_secret
      access_token_uri                = data.tfe_outputs.authentik[0].values.applications.portainer.access_token_uri
      authorization_uri               = data.tfe_outputs.authentik[0].values.applications.portainer.authorization_uri
      redirect_uri                    = data.tfe_outputs.authentik[0].values.applications.portainer.redirect_uri
      resource_uri                    = data.tfe_outputs.authentik[0].values.applications.portainer.resource_uri
      user_identifier                 = "email"
      oauth_auto_create_users         = true
      oauth_auto_map_team_memberships = false
      scopes                          = "openid profile email"
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

# These are also created on boot by portainer.service (docker network create), and
# imported here so Terraform tracks them.
import {
  for_each = toset(local.networks)
  to       = portainer_docker_network.networks[each.value]
  id       = "${var.endpoint_id}:${each.value}"
}

# Stacks are deployed and managed by Portainer (method=string from the repo's compose
# files). The copy under /opt/<stack> on the host is just a reference mirror (kept in
# sync by `make sync-portainer`); Portainer owns the actual lifecycle.
#
# v-maintenance injects its secrets (gitignored .env) straight into the
# compose via templatefile. portainer_stack has no `env` attribute, and Portainer's
# string-method deploy is flaky resolving absolute `env_file` paths on update —
# inlining avoids both.
data "local_file" "v_maintenance_env" {
  filename = "${path.module}/../../stacks/v-maintenance/v-maintenance.env"
}

locals {
  v_maintenance_isc_password = trimspace(
    element(regex("ISC_PASSWORD=(\\S+)", data.local_file.v_maintenance_env.content), 0)
  )
}

resource "portainer_stack" "stacks" {
  for_each = toset(local.stacks)

  deployment_type = "standalone"
  method          = "string"
  endpoint_id     = var.endpoint_id
  name            = each.value

  stack_file_content = each.key == "v-maintenance" ? templatefile(
    "../../stacks/${each.value}/compose.yaml",
    { ISC_PASSWORD = local.v_maintenance_isc_password }
  ) : file("../../stacks/${each.value}/compose.yaml")

  depends_on = [portainer_docker_network.networks]
}
