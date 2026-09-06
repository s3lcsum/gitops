#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)

include $(GIT_ROOT)/terraform/base.Makefile

# Inherit apply recipe from base.Makefile; just add portainer-specific prerequisites.
apply: sync-portainer untaint-all

# Host-managed files: exist only on the hosts, never in git (see .gitignore).
# Excluded from sync-portainer, which also shields them from --delete.
# Both vibe and portainer must hold a copy: pull-host-files / push-host-files.
#
# HOST_REMOTE_OWNED: the running service rewrites these itself, so portainer is
# authoritative. Divergence is normal — always pull, never push (pushing would
# clobber live config with a stale copy).
HOST_REMOTE_OWNED := \
	adguard/conf/AdGuardHome.yaml

HOST_MANAGED := \
	hass/mosquitto.passwd \
	monitoring/snmp-exporter/synology.yml

HOST_MANAGED_EXCLUDES := $(foreach f,$(HOST_MANAGED) $(HOST_REMOTE_OWNED),--exclude '$(f)')

.PHONY: sync-portainer watch-portainer sync-service untaint-all \
        pull-host-files push-host-files check-host-files

untaint-all: ## Untaint all tainted resources
	@tofu state pull | python3 -c "\
import sys, json; \
state = json.load(sys.stdin); \
[print(res['type'] + '.' + res['name'] + '[\"' + str(inst['index_key']) + '\"]') \
 for res in state.get('resources', []) \
 for inst in res.get('instances', []) \
 if inst.get('status') == 'tainted' and 'index_key' in inst]" | \
	while read addr; do tofu untaint "$$addr"; done

sync-portainer: ## Rsync stacks/ to ssh portainer:/opt (host-managed files excluded)
	-rsync -av --delete \
		$(HOST_MANAGED_EXCLUDES) \
		"$(GIT_ROOT)/stacks/" portainer:/opt

pull-host-files: ## Copy host-managed files portainer -> local (no --delete)
	@set -e; for f in $(HOST_MANAGED) $(HOST_REMOTE_OWNED); do \
		mkdir -p "$(GIT_ROOT)/stacks/$$(dirname $$f)"; \
		echo "[pull] $$f"; \
		rsync -av "portainer:/opt/$$f" "$(GIT_ROOT)/stacks/$$f"; \
	done

push-host-files: ## Copy host-managed files local -> portainer (remote-owned skipped)
	@set -e; for f in $(HOST_MANAGED); do \
		echo "[push] $$f"; \
		rsync -av "$(GIT_ROOT)/stacks/$$f" "portainer:/opt/$$f"; \
	done; \
	for f in $(HOST_REMOTE_OWNED); do echo "[skip]  $$f (service-owned: pull only)"; done

check-host-files: ## Verify host files exist on BOTH hosts; divergence fails only if not service-owned
	@set -e; rc=0; \
	for f in $(HOST_MANAGED) $(HOST_REMOTE_OWNED); do \
		l="$(GIT_ROOT)/stacks/$$f"; \
		if echo "$(HOST_REMOTE_OWNED)" | grep -qw "$$f"; then own=remote; else own=shared; fi; \
		if [ ! -f "$$l" ]; then echo "MISSING local:     $$f"; rc=1; continue; fi; \
		if ! ssh portainer "test -f /opt/$$f"; then echo "MISSING portainer: $$f"; rc=1; continue; fi; \
		lh=$$(md5 -q "$$l" 2>/dev/null || md5sum "$$l" | cut -d' ' -f1); \
		rh=$$(ssh portainer "md5sum /opt/$$f" | cut -d' ' -f1); \
		if [ "$$lh" = "$$rh" ]; then echo "ok         $$f"; \
		elif [ "$$own" = remote ]; then echo "drift      $$f (service-owned on portainer; run make pull-host-files)"; \
		else echo "DIVERGED   $$f (local $$lh / portainer $$rh)"; rc=1; fi; \
	done; exit $$rc

watch-portainer: ## Watch for changes and sync automatically
	fswatch -r --exclude '.*\.swp$$' --exclude '\.git' "$(GIT_ROOT)/stacks" | \
	while read -r _; do \
		echo "[fswatch] Change detected. Syncing..."; \
		$(MAKE)  sync-portainer; \
	done

sync-service: ## Sync portainer.service and reload systemd
	rsync -av "$(GIT_ROOT)/terraform/portainer/portainer.service" portainer:/etc/systemd/system/
	ssh portainer 'sudo systemctl daemon-reload &' || true
