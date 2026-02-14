#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: wg-genkey wg-qrconf
wg-genkey: ## Generate a new WireGuard private key
	@wg genkey

wg-qrconf: ## Show WireGuard configuration for selected PEER_NAME in text and QR code
	@configs="$$(tofu output -json wireguard_configs)" ; \
	conf="$$(jq -r --arg peer "$(PEER_NAME)" '.[$$peer].conf // empty' <<<"$$configs")" ; \
	if [ -n "$$conf" ]; then \
		printf '%s\n' "$$conf" | tee /dev/tty | qrencode -t UTF8 ; \
	else \
		echo "Available PEER_NAMEs:" ; \
		jq -r 'keys[]' <<<"$$configs" | while read -r peer; do printf "\033[35m%s\033[0m\n" "$$peer"; done ; \
	fi
