#!/usr/bin/env make -f
#
# Postgres in stacks/postgres publishes 127.0.0.1:5432 on the Portainer host only.
#
# Plan/apply from a machine that is not the host: set POSTGRES_SSH_TARGET and this
# Makefile opens an SSH local forward (127.0.0.1:POSTGRES_TUNNEL_LOCAL_PORT → remote
# 127.0.0.1:5432) for the duration of tofu plan/apply and sets TF_VAR_postgres_host /
# TF_VAR_postgres_port for that process only.
#
# Example:
#   export POSTGRES_SSH_TARGET=you@portainer-host
#   make plan
#
# Requires Terraform Cloud workspace execution mode "local" (or pure CLI) so the
# provider connects from your machine through the tunnel. Remote runs need an agent
# or other path to Postgres; leave POSTGRES_SSH_TARGET unset and use plain tofu.
#
# Optional: POSTGRES_TUNNEL_LOCAL_PORT (default 15432) if the default port is taken.

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

POSTGRES_TUNNEL_LOCAL_PORT ?= 15432

define POSTGRES_TUNNEL_RUN
bash -c 'set -euo pipefail; ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N -L 127.0.0.1:$(POSTGRES_TUNNEL_LOCAL_PORT):127.0.0.1:5432 "$(POSTGRES_SSH_TARGET)" & pid=$$!; trap "kill $$pid 2>/dev/null; wait $$pid 2>/dev/null || true" EXIT INT TERM; sleep 0.4; TF_VAR_postgres_host=127.0.0.1 TF_VAR_postgres_port=$(POSTGRES_TUNNEL_LOCAL_PORT) $(1)'
endef

plan: init
	@$(MAKE) header CMD="tofu plan"
ifeq ($(strip $(POSTGRES_SSH_TARGET)),)
	@tofu plan
else
	@$(call POSTGRES_TUNNEL_RUN,tofu plan)
endif

apply: init
	@$(MAKE) header CMD="tofu apply -auto-approve"
ifeq ($(strip $(POSTGRES_SSH_TARGET)),)
	@tofu apply -auto-approve
else
	@$(call POSTGRES_TUNNEL_RUN,tofu apply -auto-approve)
endif
