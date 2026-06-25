resource "authentik_outpost" "proxy" {
  name               = "authentik Embedded Outpost"
  protocol_providers = [for app in authentik_application.proxy : app.protocol_provider]
  config = jsonencode({
    authentik_host     = "https://auth.dominiksiejak.pl"
    authentik_insecure = "false"
  })
}
