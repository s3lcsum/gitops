########################################################
# DOCKER OUTPOST PROVIDER & APPLICATION
########################################################

# Docker outpost provider for forward authentication
resource "authentik_provider_proxy" "docker_outpost" {
  name               = "Docker Outpost"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  external_host      = "https://outpost.${local.base_domain}"
  internal_host      = "http://authentik-outpost:4180"
  mode               = "forward_single"
  skip_path_regex    = "^/outpost\\.goauthentik\\.io/.*"
}

# Application for the Docker outpost
resource "authentik_application" "docker_outpost" {
  name              = "Docker Outpost"
  slug              = "docker-outpost"
  protocol_provider = authentik_provider_proxy.docker_outpost.id
  meta_icon         = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/docker.png"
  meta_launch_url   = "https://outpost.${local.base_domain}"
}

# Service account for outpost authentication
resource "authentik_user" "outpost_service_account" {
  username = "outpost-docker"
  name     = "Docker Outpost Service Account"
  password = random_password.outpost_token.result
  type     = "service_account"
  path     = "service-accounts"
  groups = [
    authentik_group.groups["users"].id
  ]
}

# Token for outpost service account
resource "authentik_token" "outpost_token" {
  user        = authentik_user.outpost_service_account.id
  identifier  = "outpost-docker-token"
  intent      = "app_password"
  description = "Token for Docker outpost authentication"
}

# Generate a secure token for the outpost
resource "random_password" "outpost_token" {
  length  = 40
  special = false
}

