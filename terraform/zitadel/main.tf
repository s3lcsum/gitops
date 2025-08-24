# Organization
resource "zitadel_org" "home_lab" {
  name       = var.org_name
  is_default = true
}

# Human users
resource "zitadel_human_user" "users" {
  for_each = var.human_users

  org_id     = zitadel_org.home_lab.id
  user_name  = each.key
  email      = each.value.email
  first_name = each.value.first_name
  last_name  = each.value.last_name

  is_email_verified = true
  initial_password  = "Password1!"
}

resource "zitadel_org_member" "user_members" {
  for_each = {
    for k, v in var.human_users : k => v
    if length(v.roles) > 0
  }

  org_id  = zitadel_org.home_lab.id
  user_id = zitadel_human_user.users[each.key].id
  roles   = each.value.roles
}

# Organization owners
resource "zitadel_org_member" "org_owners" {
  for_each = {
    for k, v in var.human_users : k => v
    if lookup(v, "is_owner", false) == true
  }

  org_id  = zitadel_org.home_lab.id
  user_id = zitadel_human_user.users[each.key].id
  roles   = ["ORG_OWNER"]
}

# Projects
resource "zitadel_project" "projects" {
  for_each = local.projects

  org_id                   = zitadel_org.home_lab.id
  name                     = each.value.name
  project_role_assertion   = each.value.project_role_assertion
  project_role_check       = each.value.project_role_check
  has_project_check        = each.value.has_project_check
  private_labeling_setting = each.value.private_labeling_setting
}

# OIDC Applications
resource "zitadel_application_oidc" "oidc_apps" {
  for_each = local.oidc_applications

  org_id                    = zitadel_org.home_lab.id
  project_id                = zitadel_project.projects[each.value.project_key].id
  name                      = each.value.name
  redirect_uris             = each.value.redirect_uris
  response_types            = each.value.response_types
  grant_types               = each.value.grant_types
  post_logout_redirect_uris = each.value.post_logout_redirect_uris
  app_type                  = each.value.app_type
}

# Security Policies
resource "zitadel_login_policy" "homelab_login_policy" {
  org_id                        = zitadel_org.home_lab.id
  user_login                    = true
  allow_register                = false
  allow_external_idp            = true
  force_mfa                     = true
  force_mfa_local_only          = false
  passwordless_type             = "PASSWORDLESS_TYPE_ALLOWED"
  multi_factors                 = ["MULTI_FACTOR_TYPE_U2F_WITH_VERIFICATION"]
  second_factors                = ["SECOND_FACTOR_TYPE_OTP", "SECOND_FACTOR_TYPE_U2F"]
  hide_password_reset           = true
  ignore_unknown_usernames      = true
  allow_domain_discovery        = true
  default_redirect_uri          = "https://${var.zitadel_domain}/ui/v2/login"
  password_check_lifetime       = "24h0m0s"
  external_login_check_lifetime = "24h0m0s"
  mfa_init_skip_lifetime        = "720h0m0s" # 30 days
  multi_factor_check_lifetime   = "12h0m0s"
  second_factor_check_lifetime  = "18h0m0s"
  # There's a bug right now with IDP from ZITADEL app
  # idps = [zitadel_org_idp_google.google_sso.id]
}

resource "zitadel_password_complexity_policy" "homelab_password_policy" {
  org_id        = zitadel_org.home_lab.id
  min_length    = 12
  has_uppercase = true
  has_lowercase = true
  has_number    = true
  has_symbol    = true
}

resource "zitadel_password_age_policy" "homelab_password_age_policy" {
  org_id           = zitadel_org.home_lab.id
  max_age_days     = 120 # 4 months
  expire_warn_days = 30  # 30 day warning
}

resource "zitadel_lockout_policy" "homelab_lockout_policy" {
  org_id                = zitadel_org.home_lab.id
  max_password_attempts = 5
}

# Google Identity Provider for SSO (Organization-specific)
resource "zitadel_org_idp_google" "google_sso" {
  org_id              = zitadel_org.home_lab.id
  name                = "Google SSO"
  client_id           = var.google_sso.client_id
  client_secret       = var.google_sso.client_secret
  scopes              = ["openid", "profile", "email"]
  is_linking_allowed  = true
  is_creation_allowed = false
  is_auto_creation    = false
  is_auto_update      = true
  auto_linking        = "AUTO_LINKING_OPTION_EMAIL"
}
