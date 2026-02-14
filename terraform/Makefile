
#!/usr/bin/env make -f


GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

apply-all: ## Apply each terraform module in tmux separated sessions
	@for dir in $(shell ls -d */); do \
		tmux new-window -n "$$dir" "cd $(GIT_ROOT)/terraform/$$dir && make apply"; \
	done
