data "authentik_outpost" "proxy" {
  name = "authentik Embedded Outpost"
}

import {
  to = authentik_outpost.proxy
  id = data.authentik_outpost.proxy.id
}

resource "authentik_outpost" "proxy" {
  name               = "authentik Embedded Outpost"
  protocol_providers = [authentik_provider_proxy.outpost-proxy.id]
  config = jsonencode({
    AUTHENTIK_HOST     = "https://auth.lake.dominiksiejak.pl"
    AUTHENTIK_INSECURE = "false"
  })
}

resource "authentik_provider_proxy" "outpost-proxy" {
  name               = "outpost-proxy"
  mode               = "forward_domain"
  external_host      = "https://auth.lake.dominiksiejak.pl"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
}
