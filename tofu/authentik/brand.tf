resource "authentik_brand" "default" {
  domain                           = "authentik-default"
  default                          = true
  branding_title                   = "HomeLab Authentik"
  branding_logo                    = "${local.slab_brand_prefix}/logo-horizontal-dark.png"
  branding_favicon                 = "${local.slab_brand_prefix}/mark-icon.png"
  branding_default_flow_background = ""
  branding_custom_css              = file("${path.module}/slab-theme.css")

  flow_authentication = "366025e6-d668-4a7f-9c51-0a79f07e329d"
  flow_invalidation   = "a9cd8df5-123f-42fc-a5e6-1cdc00204c3e"
  flow_recovery       = authentik_flow.recovery.uuid
  flow_user_settings  = "559d4996-9c60-44b3-8166-a4b4eb170adb"
}

resource "authentik_stage_identification" "default_authentication" {
  name                      = "default-authentication-identification"
  user_fields               = ["email", "username"]
  password_stage            = null
  recovery_flow             = authentik_flow.recovery.uuid
  passwordless_flow         = authentik_flow.passwordless.uuid
  sources                   = []
  pretend_user_exists       = true
  show_matched_user         = true
  show_source_labels        = false
  enable_remember_me        = false
  case_insensitive_matching = true
}
