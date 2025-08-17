#!/usr/bin/make -f
.PHONY: help init plan apply destroy validate fmt check clean list-workspaces show-urls

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

list-workspaces: ## List all managed workspaces
	@echo "Managed Terraform Cloud Workspaces:"
	@terraform output -json workspace_urls | jq -r 'to_entries[] | "  \(.key): \(.value)"'

show-urls: ## Show workspace URLs
	@echo "Terraform Cloud Workspace URLs:"
	@terraform output workspace_urls

find-workspace-ids: ## Find existing workspace IDs for import
	@echo "Finding workspace IDs for import..."
	@echo "Run these commands to get workspace IDs:"
	@echo ""
	@echo "# Using Terraform CLI:"
	@echo "terraform workspace list"
	@echo ""
	@echo "# Using TFC API:"
	@echo "curl -H \"Authorization: Bearer \$$TFE_TOKEN\" \\"
	@echo "  https://app.terraform.io/api/v2/organizations/s3lcsum/workspaces | jq '.data[] | {name: .attributes.name, id: .id}'"

import-existing: ## Import existing workspaces (update IDs in imports.tf first)
	@echo "Importing existing workspaces..."
	@echo "Make sure to update workspace IDs in imports.tf first!"
	@terraform plan -generate-config-out=generated.tf

remove-imports: ## Remove import blocks after successful import
	@echo "Removing import blocks..."
	@rm -f imports.tf
	@echo "Import blocks removed. Run 'make plan' to verify."
