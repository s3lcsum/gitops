.PHONY: help bootstrap vendor template

CHART_VERSION ?= 10.4.0
KUBE_CONTEXT ?= kind-vibe
NAMESPACE ?= argocd
RELEASE ?= argocd
TIMEOUT ?= 10m

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install or upgrade Argo CD from the vendored chart, then register the self Application
	helm upgrade --install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--kube-context $(KUBE_CONTEXT) \
		--wait --timeout $(TIMEOUT)
	kubectl --context $(KUBE_CONTEXT) apply -f application.yaml

template: ## Render manifests from the vendored chart + values
	helm template $(RELEASE) . --namespace $(NAMESPACE)

vendor: ## Re-pull the upstream argo-cd chart into charts/argo-cd (pin CHART_VERSION)
	rm -rf charts/argo-cd
	helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
	helm repo update argo
	helm pull argo/argo-cd --version $(CHART_VERSION) --untar --untardir charts
