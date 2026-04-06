
#!/usr/bin/env make -f


GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: migrate-all-tfc

# Requires TF_TOKEN_app_terraform_io and GCP ADC (bucket dominiksiejak-gitops-tfstate must exist).
migrate-all-tfc: ## Migrate every terraform/* workspace from Terraform Cloud to GCS (state pull/push)
	@python3 "$(GIT_ROOT)/terraform/migrate_all_tfc_to_gcs.py"

apply-all: ## Apply each terraform module in tmux separated sessions
	@for dir in $(shell ls -d */); do \
		tmux new-window -n "$$dir" "cd $(GIT_ROOT)/terraform/$$dir && make apply"; \
	done
