#───────────────────────────────────────────────────────────────────────────────
# Shared Password Policy
#───────────────────────────────────────────────────────────────────────────────

resource "authentik_policy_password" "strength" {
  name                    = "password-strength"
  length_min              = 8
  amount_lowercase        = 1
  amount_uppercase        = 1
  amount_digits           = 1
  amount_symbols          = 1
  check_static_rules      = true
  check_have_i_been_pwned = true
  hibp_allowed_count      = 3
  error_message           = "Password must be at least 8 characters with 1 lowercase, 1 uppercase, 1 digit, and 1 special character."
}

#───────────────────────────────────────────────────────────────────────────────
# Password Recovery Flow
#───────────────────────────────────────────────────────────────────────────────

resource "authentik_flow" "recovery" {
  name               = "password-recovery"
  title              = "Reset your password"
  slug               = "password-recovery"
  designation        = "recovery"
  policy_engine_mode = "any"
}

# Stage 1 – Identify the user by email
resource "authentik_stage_identification" "recovery_identification" {
  name                = "recovery-identification"
  user_fields         = ["email"]
  pretend_user_exists = true
}

# Stage 2 – Send the password-reset email
resource "authentik_stage_email" "recovery_email" {
  name                     = "recovery-email"
  use_global_settings      = true
  template                 = "email/password_reset.html"
  token_expiry             = "minutes=30"
  subject                  = "Password reset request"
  activate_user_on_success = true
}

# Stage 3 – Prompt for the new password
resource "authentik_stage_prompt_field" "recovery_password" {
  name      = "recovery-password"
  field_key = "password"
  label     = "New password"
  type      = "password"
  required  = true
  order     = 0
}

resource "authentik_stage_prompt_field" "recovery_password_repeat" {
  name      = "recovery-password-repeat"
  field_key = "password_repeat"
  label     = "Confirm new password"
  type      = "password"
  required  = true
  order     = 1
}

resource "authentik_policy_expression" "recovery_password_match" {
  name       = "recovery-password-match"
  expression = <<-EOF
    if request.context.get("prompt_data", {}).get("password") != request.context.get("prompt_data", {}).get("password_repeat"):
        ak_message("Passwords do not match.")
        return False
    return True
  EOF
}

resource "authentik_stage_prompt" "recovery_password_prompt" {
  name = "recovery-password-prompt"
  fields = [
    authentik_stage_prompt_field.recovery_password.id,
    authentik_stage_prompt_field.recovery_password_repeat.id,
  ]
  validation_policies = [
    authentik_policy_password.strength.id,
    authentik_policy_expression.recovery_password_match.id,
  ]
}

# Stage 4 – Write the new password to the user
resource "authentik_stage_user_write" "recovery_user_write" {
  name                     = "recovery-user-write"
  user_creation_mode       = "never_create"
  create_users_as_inactive = false
}

# Stage 5 – Log the user in after reset
resource "authentik_stage_user_login" "recovery_login" {
  name = "recovery-login"
}

# Bind stages to the recovery flow
resource "authentik_flow_stage_binding" "recovery" {
  for_each = {
    identification = { stage = authentik_stage_identification.recovery_identification.id, order = 10 }
    email          = { stage = authentik_stage_email.recovery_email.id, order = 20 }
    password       = { stage = authentik_stage_prompt.recovery_password_prompt.id, order = 30 }
    user_write     = { stage = authentik_stage_user_write.recovery_user_write.id, order = 40 }
    login          = { stage = authentik_stage_user_login.recovery_login.id, order = 50 }
  }

  target = authentik_flow.recovery.uuid
  stage  = each.value.stage
  order  = each.value.order
}

#───────────────────────────────────────────────────────────────────────────────
# Invitation / Enrollment Flow
#───────────────────────────────────────────────────────────────────────────────

resource "authentik_flow" "invitation" {
  name               = "invitation-enrollment"
  title              = "Welcome — complete your account"
  slug               = "invitation-enrollment"
  designation        = "enrollment"
  authentication     = "require_unauthenticated"
  policy_engine_mode = "any"
}

# Stage 1 – Validate the invitation token
resource "authentik_stage_invitation" "invitation" {
  name                             = "invitation-check"
  continue_flow_without_invitation = false
}

# Stage 2 – Prompt for account details
resource "authentik_stage_prompt_field" "invitation_username" {
  name      = "invitation-username"
  field_key = "username"
  label     = "Username"
  type      = "username"
  required  = true
  order     = 0
}

resource "authentik_stage_prompt_field" "invitation_name" {
  name      = "invitation-name"
  field_key = "name"
  label     = "Full name"
  type      = "text"
  required  = true
  order     = 1
}

resource "authentik_stage_prompt_field" "invitation_email" {
  name      = "invitation-email"
  field_key = "email"
  label     = "Email"
  type      = "email"
  required  = true
  order     = 2
}

resource "authentik_stage_prompt_field" "invitation_password" {
  name      = "invitation-password"
  field_key = "password"
  label     = "Password"
  type      = "password"
  required  = true
  order     = 3
}

resource "authentik_stage_prompt_field" "invitation_password_repeat" {
  name      = "invitation-password-repeat"
  field_key = "password_repeat"
  label     = "Confirm password"
  type      = "password"
  required  = true
  order     = 4
}

resource "authentik_policy_expression" "invitation_password_match" {
  name       = "invitation-password-match"
  expression = <<-EOF
    if request.context.get("prompt_data", {}).get("password") != request.context.get("prompt_data", {}).get("password_repeat"):
        ak_message("Passwords do not match.")
        return False
    return True
  EOF
}

resource "authentik_stage_prompt" "invitation_prompt" {
  name = "invitation-account-prompt"
  fields = [
    authentik_stage_prompt_field.invitation_username.id,
    authentik_stage_prompt_field.invitation_name.id,
    authentik_stage_prompt_field.invitation_email.id,
    authentik_stage_prompt_field.invitation_password.id,
    authentik_stage_prompt_field.invitation_password_repeat.id,
  ]
  validation_policies = [
    authentik_policy_password.strength.id,
    authentik_policy_expression.invitation_password_match.id,
  ]
}

# Stage 3 – Create the user account
resource "authentik_stage_user_write" "invitation_user_write" {
  name                     = "invitation-user-write"
  user_creation_mode       = "always_create"
  create_users_as_inactive = false
  create_users_group       = authentik_group.users.id
  user_type                = "internal"
}

# Stage 4 – Log the new user in
resource "authentik_stage_user_login" "invitation_login" {
  name = "invitation-login"
}

# Bind stages to the invitation flow
resource "authentik_flow_stage_binding" "invitation" {
  for_each = {
    invitation = { stage = authentik_stage_invitation.invitation.id, order = 10 }
    prompt     = { stage = authentik_stage_prompt.invitation_prompt.id, order = 20 }
    user_write = { stage = authentik_stage_user_write.invitation_user_write.id, order = 30 }
    login      = { stage = authentik_stage_user_login.invitation_login.id, order = 40 }
  }

  target = authentik_flow.invitation.uuid
  stage  = each.value.stage
  order  = each.value.order
}
