# Adopt objects already live in Grafana Cloud. Import blocks skip once in state.
# Dashboards: omit — some UIDs never existed in Cloud; tofu creates them on apply.

import {
  to = grafana_folder.monitoring
  id = "monitoring"
}

import {
  to = grafana_folder.category["overview"]
  id = "monitoring-overview"
}

import {
  to = grafana_folder.category["kubernetes"]
  id = "monitoring-kubernetes"
}

import {
  to = grafana_folder.category["network"]
  id = "monitoring-network"
}

import {
  to = grafana_folder.category["apps"]
  id = "monitoring-apps"
}

import {
  to = grafana_data_source.victoria_metrics
  id = "victoria-metrics"
}

import {
  to = grafana_data_source.loki
  id = "loki"
}

import {
  to = grafana_rule_group.homelab_critical_workloads
  id = "monitoring:homelab-critical-workloads"
}

import {
  to = grafana_rule_group.vibe_ismc
  id = "monitoring:vibe-ismc"
}
