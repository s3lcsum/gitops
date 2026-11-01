#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)

include $(GIT_ROOT)/tofu/base.Makefile

.PHONY: import-adopt
import-adopt: ## Import pre-existing Grafana Cloud UIDs into state (see imports.tf)
	@./apply-with-import.sh
