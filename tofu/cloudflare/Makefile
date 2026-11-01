#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/tofu/base.Makefile

TF_DIR := $(abspath $(CURDIR))
TOFU   ?= tofu

.PHONY: show-token

show-token: ## Print the Cloudflare Tunnel registration secret (sensitive)
	@cd "$(TF_DIR)" && $(TOFU) output -json tunnel_secret | jq -r .

.PHONY: delete-apex-wildcard-dns
delete-apex-wildcard-dns: ## Delete legacy *.dominiksiejak.pl A (needs CF_API_TOKEN, Zone DNS Edit)
	@test -n "$(CF_API_TOKEN)" || (echo "Set CF_API_TOKEN (Zone DNS Edit on dominiksiejak.pl)" >&2; exit 1)
	@zone_id=$$(cd "$(TF_DIR)" && $(TOFU) output -raw zone_id); \
	record_id=$$(curl -fsS -G "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records" \
	  -H "Authorization: Bearer $(CF_API_TOKEN)" \
	  --data-urlencode 'type=A' \
	  --data-urlencode 'name=*.dominiksiejak.pl' \
	  | jq -r '.result[0].id // empty'); \
	if [ -z "$$record_id" ]; then \
	  echo "No *.dominiksiejak.pl A record in zone (already removed)"; \
	  exit 0; \
	fi; \
	curl -fsS -X DELETE "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records/$$record_id" \
	  -H "Authorization: Bearer $(CF_API_TOKEN)" \
	  | jq -e '.success' >/dev/null; \
	echo "Deleted *.dominiksiejak.pl A ($$record_id)"
