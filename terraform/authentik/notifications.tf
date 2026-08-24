resource "random_password" "webhook_secret" {
  length  = 32
  special = false
}

resource "authentik_property_mapping_notification" "webhook_headers" {
  name       = "n8n-firewall-webhook-headers"
  expression = <<-EOF
return {
    "Content-Type": "application/json",
    "X-Webhook-Secret": "${random_password.webhook_secret.result}",
}
EOF
}

# Authentik's default generic webhook body is {body, severity, user_email, ...}
# and does NOT include event.action or client_ip. The n8n workflow requires both.
resource "authentik_property_mapping_notification" "webhook_body" {
  name       = "n8n-firewall-webhook-body"
  expression = <<-EOF
event = notification.event
if event is None:
    return {"action": None, "client_ip": None, "user": None, "event": {}}
user = event.user or {}
return {
    "action": event.action,
    "client_ip": event.client_ip,
    "user": user,
    "event": {
        "action": event.action,
        "client_ip": event.client_ip,
        "user": user,
    },
}
EOF
}

resource "authentik_event_transport" "n8n_firewall" {
  name                    = "n8n-firewall-webhook"
  mode                    = "webhook"
  webhook_url             = "https://n8n.dominiksiejak.pl/webhook/authentik-login"
  webhook_mapping_headers = authentik_property_mapping_notification.webhook_headers.id
  webhook_mapping_body    = authentik_property_mapping_notification.webhook_body.id
  send_once               = true
}

resource "authentik_policy_event_matcher" "login_events" {
  name   = "login-events"
  action = "login"
}

resource "authentik_policy_event_matcher" "authorize_events" {
  name   = "authorize-application-events"
  action = "authorize_application"
}

resource "authentik_event_rule" "login_to_firewall" {
  name                   = "Login → Firewall Whitelist"
  severity               = "notice"
  transports             = [authentik_event_transport.n8n_firewall.id]
  destination_event_user = true
}

# Two matchers on one rule: Authentik ORs bindings that share an order group
# is not guaranteed, so use two rules instead if a single rule ANDs policies.
# Bind both as separate rules to the same transport.
resource "authentik_event_rule" "authorize_to_firewall" {
  name                   = "Authorize application → Firewall Whitelist"
  severity               = "notice"
  transports             = [authentik_event_transport.n8n_firewall.id]
  destination_event_user = true
}

resource "authentik_policy_binding" "login_event_binding" {
  target = authentik_event_rule.login_to_firewall.id
  policy = authentik_policy_event_matcher.login_events.id
  order  = 0
}

resource "authentik_policy_binding" "authorize_event_binding" {
  target = authentik_event_rule.authorize_to_firewall.id
  policy = authentik_policy_event_matcher.authorize_events.id
  order  = 0
}
