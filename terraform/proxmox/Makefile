#!/usr/bin/env make -f

GIT_ROOT := $(shell git rev-parse --show-toplevel)
include $(GIT_ROOT)/terraform/base.Makefile

TALOS_GEN := $(CURDIR)/generated

.PHONY: talos-kubeconfig talos-talosconfig bootstrap-calico
talos-kubeconfig: ## Write kubeconfig to terraform/proxmox/generated/kubeconfig (requires applied state)
	@mkdir -p $(TALOS_GEN)
	@terraform -chdir=$(CURDIR) output -raw kubeconfig > $(TALOS_GEN)/kubeconfig
	@echo "Wrote $(TALOS_GEN)/kubeconfig"

talos-talosconfig: ## Write talosconfig to terraform/proxmox/generated/talosconfig.yaml
	@mkdir -p $(TALOS_GEN)
	@terraform -chdir=$(CURDIR) output -raw talosconfig > $(TALOS_GEN)/talosconfig.yaml
	@echo "Wrote $(TALOS_GEN)/talosconfig.yaml"

# With Talos cni.name: none, install Calico once the API is reachable (same chart as Argo CD).
# Tigera operator needs pod-security privileged on tigera-operator (hostPath/hostNetwork).
# Example: KUBECONFIG=~/.kube/config make bootstrap-calico
bootstrap-calico:
	@test -n "$$KUBECONFIG" || (echo "Set KUBECONFIG (e.g. export KUBECONFIG=$$HOME/.kube/config)" && exit 1)
	@kubectl create namespace tigera-operator --dry-run=client -o yaml | kubectl apply -f -
	@kubectl label namespace tigera-operator \
		pod-security.kubernetes.io/enforce=privileged \
		pod-security.kubernetes.io/audit=privileged \
		pod-security.kubernetes.io/warn=privileged \
		--overwrite
	@cd $(GIT_ROOT)/kubernetes/platform/calico && helm dependency build && \
		helm upgrade --install calico . \
		--namespace tigera-operator --create-namespace \
		--wait --timeout 15m \
		-f values.yaml
