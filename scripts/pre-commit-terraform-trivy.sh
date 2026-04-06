#!/usr/bin/env bash
# Run Trivy on each unique Terraform root touched by staged files.
# Trivy invokes terraform internally; TERRAFORM_BINARY=tofu keeps .terraform.lock.hcl on OpenTofu registries.
set -euo pipefail
export TERRAFORM_BINARY=tofu

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

declare -A seen=()
for f in "$@"; do
  [[ "$f" == *.tf ]] || [[ "$f" == *.tfvars ]] || continue
  d="$(dirname "$f")"
  [[ -n "${seen[$d]:-}" ]] && continue
  seen[$d]=1
  (cd "$d" && trivy conf "$(pwd)" --exit-code=1)
done
