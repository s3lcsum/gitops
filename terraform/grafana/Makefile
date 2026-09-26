#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)

include $(GIT_ROOT)/terraform/base.Makefile

.PHONY: import-vm-datasource
import-vm-datasource: ## Import the UI-created VictoriaMetrics PDC datasource
	tofu import 'grafana_data_source.victoria_metrics' afzgefwo6esxsa
