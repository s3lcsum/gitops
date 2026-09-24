.PHONY: help gateway-crds bootstrap template vendor

CHART_VERSION ?= 1.20.2
GATEWAY_API_VERSION ?= v1.6.2
KUBE_CONTEXT ?= k8s@lake
NAMESPACE ?= cilium
RELEASE ?= cilium
TIMEOUT ?= 10m

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

gateway-crds: ## Install Gateway API standard CRDs (server-side; too large for Helm last-applied)
	kubectl --context $(KUBE_CONTEXT) apply --server-side --force-conflicts -f gateway-api/
	kubectl --context $(KUBE_CONTEXT) wait --for=condition=Established \
		crd/gatewayclasses.gateway.networking.k8s.io \
		crd/gateways.gateway.networking.k8s.io \
		crd/httproutes.gateway.networking.k8s.io \
		crd/grpcroutes.gateway.networking.k8s.io \
		crd/referencegrants.gateway.networking.k8s.io \
		crd/backendtlspolicies.gateway.networking.k8s.io \
		crd/tlsroutes.gateway.networking.k8s.io \
		--timeout=60s

template: ## Render manifests from the vendored chart + values
	helm template $(RELEASE) . --namespace $(NAMESPACE)

vendor: ## Re-pull the upstream cilium chart into charts/cilium (pin CHART_VERSION)
	rm -rf charts/cilium
	helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
	helm repo update cilium
	helm pull cilium/cilium --version $(CHART_VERSION) --untar --untardir charts
	rm -rf gateway-api
	mkdir -p gateway-api
	set -e; for f in \
		gateway.networking.k8s.io_gatewayclasses.yaml \
		gateway.networking.k8s.io_gateways.yaml \
		gateway.networking.k8s.io_httproutes.yaml \
		gateway.networking.k8s.io_referencegrants.yaml \
		gateway.networking.k8s.io_grpcroutes.yaml \
		gateway.networking.k8s.io_backendtlspolicies.yaml \
		gateway.networking.k8s.io_tlsroutes.yaml; do \
		curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/$(GATEWAY_API_VERSION)/config/crd/standard/$$f" \
			-o "gateway-api/$$f"; \
	done

bootstrap: gateway-crds ## Install Cilium, then drop Flannel and kube-proxy
	helm upgrade --install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--kube-context $(KUBE_CONTEXT) \
		--wait --timeout $(TIMEOUT)
	kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) rollout status ds/cilium --timeout=$(TIMEOUT)
	kubectl --context $(KUBE_CONTEXT) -n kube-flannel delete ds kube-flannel-ds --ignore-not-found
	kubectl --context $(KUBE_CONTEXT) delete ns kube-flannel --ignore-not-found --wait=true
	kubectl --context $(KUBE_CONTEXT) -n kube-system delete ds kube-proxy --ignore-not-found
	kubectl --context $(KUBE_CONTEXT) -n kube-system delete cm kube-proxy --ignore-not-found
	kubectl --context $(KUBE_CONTEXT) -n kube-system rollout restart deployment/coredns
	kubectl --context $(KUBE_CONTEXT) -n argocd rollout restart deployment
	kubectl --context $(KUBE_CONTEXT) -n argocd rollout restart statefulset
	kubectl --context $(KUBE_CONTEXT) -n external-secrets rollout restart deployment
	kubectl --context $(KUBE_CONTEXT) -n kube-system rollout status deployment/coredns --timeout=$(TIMEOUT)
	kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) rollout status deployment/cilium-operator --timeout=$(TIMEOUT)
