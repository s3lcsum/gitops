#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

# Bootstrap: apply this module on Terraform Cloud once (backend "cloud" below) to create
# gs://dominiksiejak-gitops-tfstate. Then move gitops-gcp state from TFC to GCS with:
#   make help-migrate-tfc
# (run from terraform/gcp; OpenTofu has no automatic TFC→GCS migration—use state pull/push).
# Use ADC (gcloud auth application-default login) for GCS.
#
# If the bucket was created with bootstrap-tfstate-bucket (or manually) before the first
# terraform/gcp apply, import it so state matches: from terraform/gcp after init,
#   tofu import google_storage_bucket.terraform_state dominiksiejak-gitops-tfstate

GCP_PROJECT ?= dominiksiejak
TFSTATE_BUCKET ?= dominiksiejak-gitops-tfstate

.PHONY: show-sa export-vault-key bootstrap-tfstate-bucket

# Creates gs://$(TFSTATE_BUCKET) when missing (same intent as google_storage_bucket.terraform_state in main.tf).
bootstrap-tfstate-bucket: ## Create GCS OpenTofu state bucket via gcloud if it does not exist
	@if gcloud storage buckets describe "gs://$(TFSTATE_BUCKET)" --project="$(GCP_PROJECT)" >/dev/null 2>&1; then \
		echo "Bucket gs://$(TFSTATE_BUCKET) already exists."; \
	else \
		echo "Creating gs://$(TFSTATE_BUCKET) ..."; \
		gcloud storage buckets create "gs://$(TFSTATE_BUCKET)" \
			--project="$(GCP_PROJECT)" --location=EU --uniform-bucket-level-access --pap; \
	fi
	@gcloud storage buckets update "gs://$(TFSTATE_BUCKET)" --versioning --project="$(GCP_PROJECT)"
	@echo "Bucket ready: gs://$(TFSTATE_BUCKET) (versioning on)"

show-sa: ## Show created Service Accounts
	@cd "$(TF_DIR)" && \
		echo "Service Accounts:" && \
		$(TOFU) output service_accounts

export-vault-key: ## Export Vault SA key to vault-service-account.json
	@cd "$(TF_DIR)" && \
		echo "Exporting Vault Service Account Key..." && \
		$(TOFU) output -json service_account_keys_decoded | jq -r '."vault-auto-unseal"' > vault-service-account.json && \
		echo "Key saved to vault-service-account.json"
