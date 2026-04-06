#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

TF_DIR := $(abspath $(CURDIR))
TOFU   ?= tofu

.PHONY: show-vault-unseal export-vault-key state-rm-legacy

# One-time after slimming this module: drop old resources from remote state so Terraform stops managing them (no GCP API calls).
# Deletes nothing in GCP by itself—orphans old resources; delete those in Console if you want zero spend on them (e.g. empty GCS bucket).
state-rm-legacy: ## Remove pre-slim resources from state (n8n, IAP, OAuth clients+credentials, extra APIs, tfstate bucket/SA)
	@cd "$(TF_DIR)" && \
		for r in \
			google_service_account.n8n \
			google_service_account_key.n8n \
			google_service_account.terraform_state \
			google_iap_brand.homelab \
			'google_iap_brand.homelab[0]' \
			google_iap_client.authentik \
			'google_iap_client.authentik[0]' \
			google_storage_bucket.terraform_state \
			google_storage_bucket_iam_member.terraform_state_sa \
			google_project_service.iap_api \
			'google_project_service.apis["iap.googleapis.com"]' \
			'google_project_service.apis["storage.googleapis.com"]' \
		; do \
			$(TOFU) state rm "$$r" 2>/dev/null || true; \
		done; \
		for r in $$($(TOFU) state list 2>/dev/null | grep -E '^google_iam_oauth_client(_credential)?\.'); do \
			$(TOFU) state rm "$$r" 2>/dev/null || true; \
		done; \
		echo "Done (errors ignored if address was not in state)."

# After apply: use outputs to configure Vault seal (or decode the SA key JSON for import elsewhere).
show-vault-unseal: ## Print vault_auto_unseal as JSON (sensitive; redact if sharing)
	@cd "$(TF_DIR)" && $(TOFU) output -json vault_auto_unseal | jq .

export-vault-key: ## Write Vault SA JSON key to vault-service-account.json (from Terraform output)
	@cd "$(TF_DIR)" && \
		$(TOFU) output -json vault_auto_unseal | jq -r '.service_account_key_b64 // .value.service_account_key_b64' | base64 -d > vault-service-account.json && \
		echo "Wrote vault-service-account.json"
