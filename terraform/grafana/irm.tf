resource "grafana_oncall_integration" "homelab" {
  name = "homelab-grafana-alerting"
  type = "grafana_alerting"

  default_route {
    escalation_chain_id = grafana_oncall_escalation_chain.homelab.id
  }
}

resource "grafana_oncall_escalation_chain" "homelab" {
  name = "homelab-phone"
}

resource "grafana_oncall_escalation" "notify_pager_important" {
  escalation_chain_id = grafana_oncall_escalation_chain.homelab.id
  type                = "notify_persons"
  position            = 0
  important           = true
  persons_to_notify   = [data.grafana_oncall_user.pager.id]
}

resource "grafana_contact_point" "irm" {
  name = "grafana-cloud-irm"

  webhook {
    url                     = grafana_oncall_integration.homelab.link
    http_method             = "POST"
    disable_resolve_message = false
  }
}
