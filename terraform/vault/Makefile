#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile


auth: ## Authenticate to Vault using OIDC
	VAULT_ADDR=https://vault.lake.dominiksiejak.pl vault login -method=oidc -path=oidc
