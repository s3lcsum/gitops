# OpenTofu + Terragrunt. Secrets from OpenBao KV mount secret, path <module>.
# AppRole: ~/.config/openbao/role_id and ~/.config/openbao/secret_id
# GCP ADC for state. No tfvars.

.PHONY: help auth plan apply clean
.DEFAULT_GOAL := help

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TG_FILTER ?= --filter='!./adguard' --filter='!./proxmox' --filter='!./postgres'
# Units at same DAG depth run in parallel (openbao first, then e.g. gcp + authentik + …).
TG_PARALLELISM ?= 10
# Shared provider downloads across units + caches. Disable: TG_OPTS=
TG_OPTS ?= --parallelism $(TG_PARALLELISM) --provider-cache
# Per-module OpenTofu resource concurrency (plan/apply). Override: TOFU_PARALLELISM=20
TOFU_ARGS ?=

help: ## Show targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[1;35m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "AppRole files:  ~/.config/openbao/role_id  ~/.config/openbao/secret_id"
	@echo "Secrets:        OpenBao KV secret/<module> → local.secret (ephemeral)"
	@echo "No tfvars. Nested values = JSON strings in KV."
	@echo ""
	@echo "Speed:  TG_PARALLELISM=$(TG_PARALLELISM) (stack)  TOFU_PARALLELISM via root.hcl (default 15)"
	@echo "        TG_OPTS='$(TG_OPTS)'  TOFU_ARGS='$(TOFU_ARGS)'"

plan: ## Plan all active modules, or one when MODULE=name
	@if [ -n "$(MODULE)" ]; then \
		cd "$(ROOT)/$(MODULE)" && terragrunt run --non-interactive $(TG_OPTS) -- plan $(TOFU_ARGS); \
	else \
		cd "$(ROOT)" && terragrunt run --all --non-interactive $(TG_FILTER) $(TG_OPTS) -- plan $(TOFU_ARGS); \
	fi

apply: ## Apply all active modules, or one when MODULE=name
	@if [ -n "$(MODULE)" ]; then \
		cd "$(ROOT)/$(MODULE)" && terragrunt run --non-interactive $(TG_OPTS) -- apply -auto-approve $(TOFU_ARGS); \
	else \
		cd "$(ROOT)" && terragrunt run --all --non-interactive $(TG_FILTER) $(TG_OPTS) -- apply -auto-approve $(TOFU_ARGS); \
	fi

auth: ## Write ~/.config/openbao AppRole files from OPENBAO_APPROLE_* env (CI or local)
	@set -euo pipefail; \
	if [ -z "$${OPENBAO_APPROLE_ROLE_ID:-}" ] || [ -z "$${OPENBAO_APPROLE_SECRET_ID:-}" ]; then \
		echo "Set OPENBAO_APPROLE_ROLE_ID and OPENBAO_APPROLE_SECRET_ID (local: files already at ~/.config/openbao/)" >&2; \
		exit 1; \
	fi; \
	umask 077; mkdir -p "$${HOME}/.config/openbao"; \
	printf '%s' "$${OPENBAO_APPROLE_ROLE_ID}" > "$${HOME}/.config/openbao/role_id"; \
	printf '%s' "$${OPENBAO_APPROLE_SECRET_ID}" > "$${HOME}/.config/openbao/secret_id"; \
	chmod 600 "$${HOME}/.config/openbao/role_id" "$${HOME}/.config/openbao/secret_id"

clean: ## Drop Terragrunt caches
	@find "$(ROOT)" -type d -name .terragrunt-cache -prune -exec rm -rf {} +
	@echo "cleaned .terragrunt-cache"
