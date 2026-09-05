
#!/usr/bin/env make -f


GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: migrate-all-tfc

# Requires TF_TOKEN_app_terraform_io and GCP ADC (bucket dominiksiejak-gitops-tfstate must exist).
migrate-all-tfc: ## Migrate every terraform/* workspace from Terraform Cloud to GCS (state pull/push)
	@python3 "$(GIT_ROOT)/terraform/migrate_all_tfc_to_gcs.py"

# Real tofu modules only: Makefile + providers.tf, never terraform-cloud (dead TFC bootstrap).
APPLY_MODULES := $(shell find . -maxdepth 1 -mindepth 1 -type d \
	-exec test -f '{}/Makefile' -a -f '{}/providers.tf' \; -print \
	| sed 's|^\./||' | grep -vx terraform-cloud | sort)

apply-all: ## Apply each live tofu module in tmux windows
	@for dir in $(APPLY_MODULES); do \
		tmux new-window -n "$$dir" "cd $(GIT_ROOT)/terraform/$$dir && make apply"; \
	done
