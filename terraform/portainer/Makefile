#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)

include $(GIT_ROOT)/terraform/base.Makefile

# Inherit apply recipe from base.Makefile; just add portainer-specific prerequisites.
apply: sync-portainer untaint-all

.PHONY: sync-portainer pull watch-portainer sync-service untaint-all render-secrets

PHASE_HOST ?= https://phase.dominiksiejak.pl
PHASE_TOKEN_FILE ?= $(GIT_ROOT)/.phase-service-token

render-secrets: ## Export Phase apps into stacks/*/*.env (no-op without PHASE_SERVICE_TOKEN)
	PHASE_HOST="$(PHASE_HOST)" PHASE_TOKEN_FILE="$(PHASE_TOKEN_FILE)" \
		python3 "$(GIT_ROOT)/scripts/render_phase_env.py" --dest "$(GIT_ROOT)/stacks"

untaint-all: ## Untaint all tainted resources
	@tofu state pull | python3 -c "\
import sys, json; \
state = json.load(sys.stdin); \
[print(res['type'] + '.' + res['name'] + '[\"' + str(inst['index_key']) + '\"]') \
 for res in state.get('resources', []) \
 for inst in res.get('instances', []) \
 if inst.get('status') == 'tainted' and 'index_key' in inst]" | \
	while read addr; do tofu untaint "$$addr"; done

sync-portainer: render-secrets ## Rsync stacks/ -> portainer:/opt (full mirror)
	rsync -av --delete \
		"$(GIT_ROOT)/stacks/" portainer:/opt/

pull: ## Rsync portainer:/opt -> stacks/ (compose only — secrets live in Phase)
	rsync -av --delete --exclude '*.env' \
		portainer:/opt/ "$(GIT_ROOT)/stacks/"

watch-portainer: ## Watch for changes and sync automatically
	fswatch -r --exclude '.*\.swp$$' --exclude '\.git' "$(GIT_ROOT)/stacks" | \
	while read -r _; do \
		echo "[fswatch] Change detected. Syncing..."; \
		$(MAKE)  sync-portainer; \
	done

sync-service: ## Sync portainer.service and reload systemd
	rsync -av "$(GIT_ROOT)/terraform/portainer/portainer.service" portainer:/etc/systemd/system/
	ssh portainer 'sudo systemctl daemon-reload &' || true
