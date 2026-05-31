GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

destroy: init ## Destroy the cluster managed by this module
	@$(MAKE) header CMD="tofu destroy -auto-approve"
	@tofu destroy -auto-approve
