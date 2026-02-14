#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile


.PHONY: show-sa export-vault-key

show-sa: ## Show created Service Accounts
	@cd "$(TF_DIR)" && \
		echo "Service Accounts:" && \
		$(TOFU) output service_accounts

export-vault-key: ## Export Vault SA key to vault-service-account.json
	@cd "$(TF_DIR)" && \
		echo "Exporting Vault Service Account Key..." && \
		$(TOFU) output -json service_account_keys_decoded | jq -r '."vault-auto-unseal"' > vault-service-account.json && \
		echo "Key saved to vault-service-account.json"
