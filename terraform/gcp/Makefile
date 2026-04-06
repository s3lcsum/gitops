#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

# Bootstrap: apply this module on Terraform Cloud once (backend "cloud" below) to create
# gs://dominiksiejak-gitops-tfstate. Then replace the cloud {} block in providers.tf with
# backend "gcs" { bucket = "dominiksiejak-gitops-tfstate" prefix = "gitops-gcp" } and run:
#   $(TOFU) init -migrate-state
# For every other terraform/* module already on GCS: same init -migrate-state with GCP ADC.

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
