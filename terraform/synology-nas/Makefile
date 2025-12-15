#!/usr/bin/make -f
.PHONY: help init plan apply destroy validate fmt check clean show-config test-connection

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

show-config: ## Show current configuration
	@echo "Synology NAS Configuration:"
	@terraform output configuration_summary
	@echo ""
	@echo "Shared Folders:"
	@terraform output shared_folder_names
	@echo ""
	@echo "Users:"
	@terraform output user_names

test-connection: ## Test connection to Synology NAS
	@echo "Testing connection to Synology NAS..."
	@if command -v curl >/dev/null 2>&1; then \
		echo "Testing basic connectivity to $$(terraform output -raw synology_host)..."; \
		curl -k --connect-timeout 10 "https://$$(terraform output -raw synology_host):5001/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query" >/dev/null 2>&1 && \
		echo "✓ Connection successful" || echo "✗ Connection failed"; \
	else \
		echo "curl not installed. Install curl to test connectivity."; \
	fi
