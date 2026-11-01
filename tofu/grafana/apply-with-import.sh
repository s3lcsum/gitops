#!/usr/bin/env bash
# One-shot adopt of pre-existing Grafana Cloud objects into state, then apply.
set -euo pipefail
cd "$(dirname "$0")"

run() {
  if [[ -f terragrunt.hcl ]]; then
    terragrunt run --non-interactive -- "$@"
  else
    tofu "$@"
  fi
}

run init -input=false

ti_import() {
  run import "$1" "$2" || true
}

ti_import 'grafana_folder.monitoring' monitoring
ti_import 'grafana_folder.category["overview"]' monitoring-overview
ti_import 'grafana_folder.category["kubernetes"]' monitoring-kubernetes
ti_import 'grafana_folder.category["network"]' monitoring-network
ti_import 'grafana_folder.category["apps"]' monitoring-apps
ti_import 'grafana_data_source.victoria_metrics' victoria-metrics
ti_import 'grafana_data_source.loki' loki
ti_import 'grafana_rule_group.homelab_critical_workloads' 'monitoring:homelab-critical-workloads'
ti_import 'grafana_rule_group.vibe_ismc' 'monitoring:vibe-ismc'

run apply -auto-approve
