# # Terraform Cloud outputs from other workspaces
# data "tfe_outputs" "gcp" {
#   organization = "s3lcsum"
#   workspace    = "gitops-gcp"
# }

# Default flows from Authentik
data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-authentication-flow" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "default-source-authentication" {
  slug = "default-source-authentication"
}

data "authentik_flow" "default-source-enrollment" {
  slug = "default-source-enrollment"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-invalidation-flow"
}

# Default property mappings
data "authentik_property_mapping_provider_scope" "oauth2_scopes" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}

# Certificate for signing
data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}
