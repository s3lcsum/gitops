#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

TF_DIR := $(abspath $(CURDIR))
TOFU   ?= tofu

.PHONY: show-token

show-token: ## Print the Cloudflared tunnel token (sensitive)
	@cd "$(TF_DIR)" && $(TOFU) output -json tunnel_token | jq -r .
