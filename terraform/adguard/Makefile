#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: import-existing

# Import live rewrites. Already-imported addresses print an error and continue.
import-existing: init ## Import existing AdGuard DNS rewrites into state
	@python3 -c 'import re,pathlib; t=pathlib.Path("locals.tf").read_text(); \
pairs=re.findall(r"\"([^\"]+)\"\s*=\s*\"([0-9.]+)\"", t); \
print("\n".join(f"{d}||{a}" for d,a in pairs))' | while IFS= read -r id; do \
	  domain="$${id%%||*}"; \
	  tofu import "adguard_rewrite.this[\"$$domain\"]" "$$id" || true; \
	done
