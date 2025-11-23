#!/usr/bin/make -f
.PHONY: help init plan apply destroy validate fmt check clean

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

show-sa: ## Show created Service Accounts
	@echo "Service Accounts:"
	@terraform output service_accounts

export-vault-key: ## Export Vault SA key to vault-service-account.json
	@echo "Exporting Vault Service Account Key..."
	@terraform output -json service_account_keys_decoded | jq -r '."vault-auto-unseal"' > vault-service-account.json
	@echo "Key saved to vault-service-account.json"

