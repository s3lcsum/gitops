#!/usr/bin/env make -f

# DEAD MODULE — TFC bootstrap. State lives in GCS now. Do not apply.
GIT_ROOT := $(shell git rev-parse --show-toplevel)

.PHONY: init plan apply destroy validate fmt check clean

refuse:
	@echo "REFUSE: terraform/terraform-cloud is retired (TFC→GCS). Do not apply." >&2
	@echo "Use flat modules under terraform/<name>/ with GCS backends." >&2
	@exit 1

init plan apply destroy validate check: refuse

fmt:
	@true

clean:
	rm -rf .terraform
