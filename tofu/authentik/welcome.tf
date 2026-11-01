# Welcome email when a user is created (tofu, API, admin UI, enrollment).
# Uses ak_send_email — no notification transport on the rule (see Authentik docs:
# Notification Rule Expression Policies → "Send a welcome email to newly created users").
resource "authentik_policy_expression" "welcome_email" {
  name       = "send-welcome-email"
  expression = <<-EOF
from authentik.core.models import User

event = request.context.get("event")
if not event or event.action != "model_created":
    return False

model = event.context.get("model", {})
if model.get("app") != "authentik_core" or model.get("model_name") != "user":
    return False

user = User.objects.filter(pk=model.get("pk")).first()
if not user or user.type != "internal":
    return False
if not user.email:
    return False
local_part = user.email.split("@", 1)[0]
if user.email.endswith("@dominiksiejak.pl") and local_part in ("null", "test", "noreply"):
    return False

recovery_url = "https://${local.cfg.authentik_domain}/if/flow/${authentik_flow.recovery.slug}/"
ak_send_email(
    user.email,
    "Welcome — set your password",
    template="email/welcome.html",
    context={
        "user": user,
        "recovery_url": recovery_url,
        "site_name": "${local.base_domain}",
    },
)
return False
EOF
}

resource "authentik_event_rule" "welcome_email" {
  name       = "Welcome email on user create"
  severity   = "notice"
  transports = []
}

resource "authentik_policy_binding" "welcome_email" {
  target = authentik_event_rule.welcome_email.id
  policy = authentik_policy_expression.welcome_email.id
  order  = 0
}
