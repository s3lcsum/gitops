#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile


.PHONY: show-config

show-config: ## Show backup buckets + keys as YAML (SENSITIVE)
	@cd "$(TF_DIR)" && \
		OUTPUT=$$($(TOFU) output -json); \
		echo "=== Backblaze Backup Config (SENSITIVE) ===" && \
		echo "$$OUTPUT" | jq ".config.value" | yq eval -P
