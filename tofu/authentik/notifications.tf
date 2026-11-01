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
import ipaddress

# https://www.cloudflare.com/ips-v4/ — never whitelist CF anycast on RouterOS WAN.
CLOUDFLARE_IPV4 = [
    ipaddress.ip_network(n)
    for n in (
        "103.21.244.0/22",
        "103.22.200.0/22",
        "103.31.4.0/22",
        "104.16.0.0/12",
        "104.24.0.0/14",
        "108.162.192.0/18",
        "131.0.72.0/22",
        "141.101.64.0/18",
        "162.158.0.0/15",
        "172.64.0.0/13",
        "173.245.48.0/20",
        "188.114.96.0/20",
        "190.93.240.0/20",
        "197.234.240.0/22",
        "198.41.128.0/17",
    )
]


def is_cloudflare_ipv4(addr):
    return any(addr in net for net in CLOUDFLARE_IPV4)


def public_ipv4(value):
    if value is None:
        return None
    text = str(value).strip()
    if not text or ":" in text:
        return None
    try:
        addr = ipaddress.ip_address(text)
    except ValueError:
        return None
    if not isinstance(addr, ipaddress.IPv4Address):
        return None
    if (
        addr.is_private
        or addr.is_loopback
        or addr.is_link_local
        or addr.is_multicast
        or addr.is_reserved
        or addr.is_unspecified
    ):
        return None
    if addr in ipaddress.ip_network("100.64.0.0/10"):
        return None
    if is_cloudflare_ipv4(addr):
        return None
    return str(addr)

event = notification.event
if event is None:
    return {"action": None, "client_ip": None, "user": None, "event": {}}
user = event.user or {}
client_ip = public_ipv4(event.client_ip)
return {
    "action": event.action,
    "client_ip": client_ip,
    "user": user,
    "event": {
        "action": event.action,
        "client_ip": client_ip,
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
