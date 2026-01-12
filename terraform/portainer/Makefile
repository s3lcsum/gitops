#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: sync-portainer watch-portainer sync-service sync-apply

sync-apply:
	-$(MAKE) sync-portainer
	$(MAKE) apply

sync-portainer: ## Rsync stacks/ to ssh portainer:/opt
	rsync -av --delete "$(GIT_ROOT)/stacks/" portainer:/opt

watch-portainer: ## Watch for changes and sync automatically
	fswatch -r --exclude '.*\.swp$$' --exclude '\.git' "$(GIT_ROOT)/stacks" | \
	while read -r _; do \
		echo "[fswatch] Change detected. Syncing..."; \
		$(MAKE)  sync-portainer; \
	done

sync-service: ## Sync portainer.service and reload systemd
	rsync -av "$(GIT_ROOT)/terraform/portainer/portainer.service" portainer:/etc/systemd/system/
	ssh portainer 'sudo systemctl daemon-reload &' || true
