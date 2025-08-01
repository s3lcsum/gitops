#!/usr/bin/make -f
.PHONY: help init plan apply destroy validate fmt check clean sync-portainer watch-portainer sync-service

# Define the root directory
ROOT := $(shell git rev-parse --show-toplevel)

help:
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s - %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

plan: ## Create an execution plan
	terraform plan

sync-portainer: ## Rsync stacks/ to ssh portainer:/Portainer
	rsync -av --delete $(ROOT)/stacks/ portainer:/Portainer

watch-portainer: ## Watch for changes and sync automatically
	fswatch -r --exclude '.*\.swp$$' --exclude '\.git' "$(ROOT)/stacks" | \
	while read -r _; do \
		echo "[fswatch] Change detected. Syncing..."; \
		make sync-portainer; \
	done

sync-service: ## Sync portainer.service and reload systemd
	rsync -av $(ROOT)/terraform/portainer/portainer.service portainer:/etc/systemd/system/
	ssh portainer 'sudo systemctl daemon-reload &' || true

apply: sync-portainer sync-service ## Apply the configuration (with auto-approve)
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
