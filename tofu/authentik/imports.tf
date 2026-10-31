import {
  to = authentik_brand.default
  id = "b71a6d7a-51af-4210-b5f6-203f967f9df0"
}

import {
  to = authentik_stage_identification.default_authentication
  id = "8233c182-a3ee-468d-a32f-cf770027b772"
}

# Created via Authentik API (proxy provider + application) before tofu config
# carried `opencode`. Adopting keeps the client_id and outpost binding.
import {
  to = authentik_provider_proxy.proxy["opencode"]
  id = "90"
}

import {
  to = authentik_application.proxy["opencode"]
  # authentik_application import uses the slug, not the UUID (API path is
  # /core/applications/<slug>/). UUID lookup returns 404.
  id = "opencode"
}
