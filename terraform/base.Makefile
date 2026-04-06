#!/usr/bin/env make -f

# Shared OpenTofu make targets for terraform/* modules.

.PHONY: help header init plan apply destroy validate fmt pre-apply pre-destroy help-migrate-tfc migrate-tfc-pull migrate-tfc-push
.DEFAULT_GOAL := help

# TFC → GCS (OpenTofu cannot migrate automatically). Run from this module directory, e.g. cd terraform/portainer && make migrate-tfc-pull
# Default state file and GCS prefix follow workspace naming: gitops-<directory-name>
MIGRATE_STATE_FILE ?= /tmp/migrate-$(notdir $(CURDIR)).tfstate
GITOPS_PREFIX ?= gitops-$(notdir $(CURDIR))
# Set MIGRATE_FORCE=1 if state push refuses (e.g. empty remote) — use only when you understand the risk
MIGRATE_FORCE ?=

header: ## Show header for this module/command
	@c="$${CMD:-}"; p="\033[1;35m"; r="\033[0m"; \
	echo "$$p=========================================="; \
	[ -n "$$c" ] && echo "==>  $$c"; \
	echo "==========================================$$r"

# Example: Run with CMD="tofu plan" make header

help: ## Show available targets
	@purple="\033[1;35m"; reset="\033[0m"; \
	echo "Available targets:"; \
	awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_.-]+:.*?## / {printf "  \033[1;35m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# OpenTofu does not migrate Terraform Cloud (cloud {}) → GCS automatically ("not yet implemented").
# Use this once per workspace, from this module directory, with TF_TOKEN_app_terraform_io and GCP ADC.
help-migrate-tfc: ## Print manual TFC → GCS state migration (state pull / state push)
	@echo ""
	@echo "OpenTofu cannot auto-migrate from the Terraform Cloud backend. Use:"
	@echo ""
	@echo "  1) Restore terraform { cloud { ... } } in providers.tf (same org/workspace as before)."
	@echo "  2) rm -rf .terraform && tofu init"
	@echo "  3) tofu state pull > /tmp/migrate-$$(basename $$(pwd)).tfstate"
	@echo "  4) Replace cloud {} with backend \"gcs\" { bucket = \"dominiksiejak-gitops-tfstate\" prefix = \"gitops-$$(basename $$(pwd))\" }."
	@echo "  5) rm -rf .terraform && tofu init"
	@echo "  6) tofu state push /tmp/migrate-$$(basename $$(pwd)).tfstate"
	@echo "  7) tofu plan   # expect no surprise destroys"
	@echo ""
	@echo "GCS prefix must match the old TFC workspace name (this repo uses gitops-<dirname>, e.g. gitops-portainer)."
	@echo ""
	@echo "Batch (all modules): from repo root, make -C terraform migrate-all-tfc"
	@echo "Or use: make migrate-tfc-pull  (with cloud {} in providers.tf)"
	@echo "        # then set backend gcs (bucket dominiksiejak-gitops-tfstate, prefix $(GITOPS_PREFIX))"
	@echo "        make migrate-tfc-push"
	@echo ""

# Step 1: providers.tf must use Terraform Cloud backend. Exports state to MIGRATE_STATE_FILE (default /tmp/migrate-<dirname>.tfstate).
migrate-tfc-pull: ## Pull state from Terraform Cloud (requires cloud {} in providers.tf; set TF_TOKEN_app_terraform_io)
	@test -f providers.tf || { echo "Run from a terraform module directory (providers.tf not found)."; exit 1; }
	@grep -q 'app.terraform.io' providers.tf && grep -E -q '^[[:space:]]*cloud[[:space:]]*\{' providers.tf || { echo "providers.tf must use Terraform Cloud (cloud {} with app.terraform.io)."; exit 1; }
	@echo "Writing state to $(MIGRATE_STATE_FILE) (prefix hint: $(GITOPS_PREFIX))"
	rm -rf .terraform
	tofu init -input=false
	tofu state pull > $(MIGRATE_STATE_FILE)
	@echo ""
	@echo "Next: edit providers.tf — replace cloud {} with:"
	@echo '  backend "gcs" { bucket = "dominiksiejak-gitops-tfstate" prefix = "$(GITOPS_PREFIX)" }'
	@echo "Then: make migrate-tfc-push   (needs GCP ADC for the bucket)"
	@echo ""

# Step 2: providers.tf must use backend "gcs". Pushes MIGRATE_STATE_FILE into the bucket.
migrate-tfc-push: ## Push saved state file to GCS (requires backend gcs in providers.tf; set MIGRATE_FORCE=1 to pass -force)
	@test -f providers.tf || { echo "Run from a terraform module directory (providers.tf not found)."; exit 1; }
	@grep -q 'backend "gcs"' providers.tf || { echo "providers.tf must use backend \"gcs\"."; exit 1; }
	@test -f $(MIGRATE_STATE_FILE) || { echo "Missing $(MIGRATE_STATE_FILE). Run migrate-tfc-pull first."; exit 1; }
	rm -rf .terraform
	tofu init -input=false
	@if [ "$(MIGRATE_FORCE)" = "1" ]; then \
		tofu state push -force $(MIGRATE_STATE_FILE); \
	else \
		tofu state push $(MIGRATE_STATE_FILE); \
	fi
	@echo ""
	@echo "Done. Run: tofu plan"
	@echo ""


init: ## Initialize OpenTofu
	@$(MAKE) header CMD="tofu init"
	@tofu init

plan: init ## Create an execution plan
	@$(MAKE) header CMD="tofu plan"
	@tofu plan

apply: init ## Apply the configuration (with auto-approve)
	@$(MAKE) header CMD="tofu apply -auto-approve"
	@tofu apply -auto-approve
