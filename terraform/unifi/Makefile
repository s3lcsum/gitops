#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: import-existing

# Import live controller objects into state (idempotent-ish — fails if already imported).
import-existing: init ## Import existing UniFi WLANs + U7 Lite into state
	@tofu import unifi_wlan.hass 6ab6ef82344af8ab44b6f709 || true
	@tofu import unifi_wlan.raval 6a45980f9eeb974e35544ca7 || true
	@tofu import unifi_device.u7_lite 6a456b929929e1d859fb0f5c || true
