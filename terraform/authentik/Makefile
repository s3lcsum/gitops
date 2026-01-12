#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: show-config

show-config: ## Show OAuth configurations and LDAP service accounts as YAML
	@cd "$(TF_DIR)" && \
		OUTPUT=$$($(TOFU) output -json); \
		echo "=== Applications ===" && \
		echo "$$OUTPUT" | jq ".applications.value" | yq eval -P && \
		echo "" && \
		echo "=== LDAP Service Accounts ===" && \
		echo "$$OUTPUT" | jq ".ldap_service_accounts.value" | yq eval -P
