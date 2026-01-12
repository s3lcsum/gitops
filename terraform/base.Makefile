#!/usr/bin/env make -f

# Shared OpenTofu make targets for terraform/* modules.

.PHONY: help header init plan apply destroy validate fmt pre-apply pre-destroy
.DEFAULT_GOAL := help

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


init: ## Initialize OpenTofu
	@$(MAKE) header CMD="tofu init"
	@tofu init

plan: init ## Create an execution plan
	@$(MAKE) header CMD="tofu plan"
	@tofu plan

apply: init ## Apply the configuration (with auto-approve)
	@$(MAKE) header CMD="tofu apply -auto-approve"
	@tofu apply -auto-approve