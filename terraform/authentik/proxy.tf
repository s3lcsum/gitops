resource "authentik_outpost" "proxy" {
  name               = "authentik Embedded Outpost"
  protocol_providers = [for app in authentik_application.proxy : app.protocol_provider]
  service_connection = authentik_service_connection_docker.local.id
  config = jsonencode({
    authentik_host     = "https://auth.dominiksiejak.pl"
    authentik_insecure = "false"
  })
}
