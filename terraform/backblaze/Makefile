#!/usr/bin/make -f
.PHONY: help init plan apply destroy validate fmt check clean show-keys test-connection

help:
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s - %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

plan: ## Create an execution plan
	terraform plan

apply: ## Apply the configuration (with auto-approve)
	terraform apply -auto-approve

destroy: ## Destroy the infrastructure (with auto-approve)
	terraform destroy -auto-approve

validate: ## Validate the configuration
	terraform validate

fmt: ## Format the configuration files
	terraform fmt

check: validate fmt ## Run validate and fmt

clean: ## Clean up temporary files
	rm -rf .terraform/
	rm -f terraform.tfstate.backup
	rm -f .terraform.lock.hcl

show-keys: ## Show all application keys (sensitive output)
	@echo "All Backup Keys:"
	@terraform output backup_key_ids
	@echo ""
	@terraform output backup_keys

test-connection: ## Test B2 connection with current credentials
	@echo "Testing Backblaze B2 connection..."
	@if command -v b2 >/dev/null 2>&1; then \
		b2 authorize-account $$(terraform output -raw atom_1_hass_backup_key_id) $$(terraform output -raw atom_1_hass_backup_key) && \
		b2 list-buckets | grep -E "(atom-1|wally-1)"; \
	else \
		echo "b2 CLI not installed. Install with: pip install b2"; \
	fi

list-buckets: ## List all created buckets
	@echo "Created buckets:"
	@terraform output bucket_names
