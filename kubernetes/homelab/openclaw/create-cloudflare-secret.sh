#!/usr/bin/env bash
# Creates the secret cert-manager needs for DNS-01 (Cloudflare).
# Usage: export CLOUDFLARE_API_TOKEN='...' && ./create-cloudflare-secret.sh
set -euo pipefail
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "Set CLOUDFLARE_API_TOKEN to a Cloudflare API token with DNS:Edit for dominiksiejak.pl" >&2
  exit 1
fi
kubectl create secret generic cloudflare-api-token -n cert-manager \
  --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
