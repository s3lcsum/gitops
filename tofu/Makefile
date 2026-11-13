# OpenTofu + Terragrunt. Secrets from OpenBao KV mount secret, path <module>.
# OpenBao login: AppRole env (OPENBAO_APPROLE_* or BAO_*), else Google ID token
# for github-actions-tofu (CI), else interactive OIDC. Writes
# ~/.config/openbao/token.env. AppRole files are the fallback.
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
	@echo "OpenBao:        AppRole env -> GCP ID token -> interactive OIDC (token.env)"
	@echo "Secrets:        OpenBao KV secret/<module> → local.secret (ephemeral)"
	@echo "No tfvars. Nested values = JSON strings in KV."
	@echo ""
	@echo "Speed:  TG_PARALLELISM=$(TG_PARALLELISM) (stack)  TOFU_PARALLELISM via root.hcl (default 15)"
	@echo "        TG_OPTS='$(TG_OPTS)'  TOFU_ARGS='$(TOFU_ARGS)'"

# Load VAULT_TOKEN from the gcp login file when the shell has none.
LOAD_TOKEN = set -euo pipefail; \
	if [ -z "$${VAULT_TOKEN:-}" ] && [ -f "$${HOME}/.config/openbao/token.env" ]; then \
		set -a; . "$${HOME}/.config/openbao/token.env"; set +a; \
	fi;

plan: ## Plan all active modules, or one when MODULE=name
	@$(LOAD_TOKEN) \
	if [ -n "$(MODULE)" ]; then \
		cd "$(ROOT)/$(MODULE)" && terragrunt run --non-interactive $(TG_OPTS) -- plan $(TOFU_ARGS); \
	else \
		cd "$(ROOT)" && terragrunt run --all --non-interactive $(TG_FILTER) $(TG_OPTS) -- plan $(TOFU_ARGS); \
	fi

apply: ## Apply all active modules, or one when MODULE=name
	@$(LOAD_TOKEN) \
	if [ -n "$(MODULE)" ]; then \
		cd "$(ROOT)/$(MODULE)" && terragrunt run --non-interactive $(TG_OPTS) -- apply -auto-approve $(TOFU_ARGS); \
	else \
		cd "$(ROOT)" && terragrunt run --all --non-interactive $(TG_FILTER) $(TG_OPTS) -- apply -auto-approve $(TOFU_ARGS); \
	fi

auth: ## OpenBao login: AppRole env, else Google ID token, else interactive OIDC
	@set -euo pipefail; \
	umask 077; mkdir -p "$${HOME}/.config/openbao"; \
	role_id="$${OPENBAO_APPROLE_ROLE_ID:-$${BAO_ROLE_ID:-}}"; \
	secret_id="$${OPENBAO_APPROLE_SECRET_ID:-$${BAO_SECRET_ID:-}}"; \
	export VAULT_ADDR="$${VAULT_ADDR:-https://bao.dominiksiejak.pl}"; \
	token=""; \
	if [ -n "$$role_id" ] && [ -n "$$secret_id" ]; then \
		echo "openbao: AppRole login" >&2; \
		token="$$(vault write -field=token auth/approle/login role_id="$$role_id" secret_id="$$secret_id")"; \
	elif [ -n "$${GCP_ID_TOKEN:-}" ]; then \
		"$(ROOT)/scripts/openbao-gcp-login.sh"; \
		exit 0; \
	else \
		echo "openbao: OIDC login (browser)" >&2; \
		token="$$(vault login -method=oidc -token-only)"; \
	fi; \
	printf 'VAULT_TOKEN=%s\n' "$$token" > "$${HOME}/.config/openbao/token.env"; \
	echo "openbao: token -> ~/.config/openbao/token.env"

clean: ## Drop Terragrunt caches
	@find "$(ROOT)" -type d -name .terragrunt-cache -prune -exec rm -rf {} +
	@echo "cleaned .terragrunt-cache"
