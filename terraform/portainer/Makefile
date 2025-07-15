#!/usr/bin/make -f
.PHONY: help init plan apply destroy validate fmt check clean

# Define the root directory
ROOT := $(shell git rev-parse --show-toplevel)

# Default target
help:
	@echo "Available targets:"
	@echo "  init           - Initialize Terraform"
	@echo "  plan           - Create an execution plan"
	@echo "  sync-portainer - Rsync stacks/ to ssh portainer:/Portainer"
	@echo "  apply          - Apply the configuration (with auto-approve)"
	@echo "  destroy        - Destroy the infrastructure (with auto-approve)"
	@echo "  validate       - Validate the configuration"
	@echo "  fmt            - Format the configuration files"
	@echo "  check          - Run validate and fmt"
	@echo "  clean          - Clean up temporary files"

# Initialize Terraform
init:
	terraform init

# Create execution plan
plan:
	terraform plan

# Sync stacks to Portainer host
sync-portainer:
	rsync -av $(ROOT)/stacks/ portainer:/Portainer
#	rsync -av --delete $(ROOT)/../../stacks/ portainer:/Portainer

# Apply configuration with auto-approve
apply: sync-portainer
	terraform apply -auto-approve

# Destroy infrastructure with auto-approve
destroy:
	terraform destroy -auto-approve

# Validate configuration
validate:
	terraform validate

# Format configuration files
fmt:
	terraform fmt

# Run validation and formatting checks
check: validate fmt

# Clean up temporary files
clean:
	rm -rf .terraform/
	rm -f terraform.tfstate.backup
	rm -f .terraform.lock.hcl
