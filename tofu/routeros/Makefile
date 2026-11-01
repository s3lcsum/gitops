#!/usr/bin/env make -f

TF_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TOFU   ?= tofu

.PHONY: help wg-genkey wg-qrconf
.DEFAULT_GOAL := help

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_.-]+:.*?## / {printf "  \033[1;35m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

wg-genkey: ## Generate a new WireGuard private key
	@wg genkey

wg-qrconf: ## Show WireGuard configuration for selected PEER_NAME in text and QR code
	@cd "$(TF_DIR)" && \
		configs="$$($(TOFU) output -json wireguard_configs)" ; \
		conf="$$(jq -r --arg peer "$(PEER_NAME)" '.[$$peer].conf // empty' <<<"$$configs")" ; \
		if [ -n "$$conf" ]; then \
			printf '%s\n' "$$conf" | tee /dev/tty | qrencode -t UTF8 ; \
		else \
			echo "Available PEER_NAMEs:" ; \
			jq -r 'keys[]' <<<"$$configs" | while read -r peer; do printf "\033[35m%s\033[0m\n" "$$peer"; done ; \
		fi
