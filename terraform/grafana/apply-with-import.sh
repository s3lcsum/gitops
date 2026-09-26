#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -f defaults.auto.tfvars ]]; then
  echo "Missing defaults.auto.tfvars — copy defaults.auto.tfvars.example and set grafana_cloud_auth to a Cloud Admin glsa_ token." >&2
  echo "Create token: https://dreewniak.grafana.net/org/serviceaccounts" >&2
  exit 1
fi
tofu init -input=false
tofu import 'grafana_folder.monitoring' monitoring || true
tofu import 'grafana_data_source.victoria_metrics' afzgefwo6esxsa || true
tofu import 'grafana_rule_group.synthetic_page' monitoring:synthetic-page-call || true
make apply
