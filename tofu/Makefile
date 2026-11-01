# OpenTofu + Terragrunt. Secrets from OpenBao provider (secret/terraform_env/<module>).
# AppRole: ~/.config/openbao/role_id and ~/.config/openbao/secret_id
# GCP ADC for state. No tfvars.

.PHONY: help plan apply clean
.DEFAULT_GOAL := help

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TG_FILTER ?= --filter='!./adguard' --filter='!./proxmox' --filter='!./postgres' --filter='!./gitea'

help: ## Show targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[1;35m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "AppRole files:  ~/.config/openbao/role_id  ~/.config/openbao/secret_id"
	@echo "Secrets:        OpenBao KV secret/terraform_env/<module> → local.env (provider)"
	@echo "No tfvars. Nested values = JSON strings in KV."

plan: ## Plan all active modules, or one when MODULE=name
	@if [ -n "$(MODULE)" ]; then \
		cd "$(ROOT)/$(MODULE)" && terragrunt run --non-interactive -- plan; \
	else \
		cd "$(ROOT)" && terragrunt run --all --non-interactive $(TG_FILTER) -- plan; \
	fi

apply: ## Apply all active modules, or one when MODULE=name
	@if [ -n "$(MODULE)" ]; then \
		cd "$(ROOT)/$(MODULE)" && terragrunt run --non-interactive -- apply -auto-approve; \
	else \
		cd "$(ROOT)" && terragrunt run --all --non-interactive $(TG_FILTER) -- apply; \
	fi

clean: ## Drop Terragrunt caches
	@find "$(ROOT)" -type d -name .terragrunt-cache -prune -exec rm -rf {} +
	@echo "cleaned .terragrunt-cache"
