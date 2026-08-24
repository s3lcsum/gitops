#!/usr/bin/env make -f
#
# Postgres runs in Docker on the Portainer host (stacks/postgres), bound to 0.0.0.0:5432
# but locally-only by intent. Plan/apply from a machine that cannot reach the host's
# postgres port directly (e.g. dual-interface Mac route quirks) by setting POSTGRES_SSH_TARGET;
# this Makefile opens an SSH local forward (127.0.0.1:POSTGRES_TUNNEL_LOCAL_PORT -> remote
# 127.0.0.1:5432) for the duration of tofu plan/apply and passes postgres_host/port via -var
# (which overrides defaults.auto.tfvars; OpenTofu gives auto.tfvars precedence over TF_VAR_*).
#
# Example:
#   export POSTGRES_SSH_TARGET=portainer   # ~/.ssh/config host
#   make plan
#
# Leave POSTGRES_SSH_TARGET unset and tofu connects to the host/port in defaults.auto.tfvars
# (POSTGRES_TUNNEL_LOCAL_PORT default 15432).

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

POSTGRES_TUNNEL_LOCAL_PORT ?= 15432

define POSTGRES_TUNNEL_RUN
bash -c 'set -euo pipefail; ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N -L 127.0.0.1:$(POSTGRES_TUNNEL_LOCAL_PORT):127.0.0.1:5432 "$(POSTGRES_SSH_TARGET)" & pid=$$!; trap "kill $$pid 2>/dev/null; wait $$pid 2>/dev/null || true" EXIT INT TERM; sleep 0.4; $(1) -var=postgres_host=127.0.0.1 -var=postgres_port=$(POSTGRES_TUNNEL_LOCAL_PORT)'
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
