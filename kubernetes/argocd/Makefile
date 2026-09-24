.PHONY: help bootstrap template vendor

CHART_VERSION ?= 10.4.0
KUBE_CONTEXT ?= k8s@lake
NAMESPACE ?= argocd
RELEASE ?= argocd
TIMEOUT ?= 10m

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install or upgrade Argo CD (CRDs first, then the vendored chart)
	helm template $(RELEASE) . --namespace $(NAMESPACE) \
		-s charts/argo-cd/templates/crds/crd-application.yaml \
		-s charts/argo-cd/templates/crds/crd-appproject.yaml \
		-s charts/argo-cd/templates/crds/crd-applicationset.yaml \
		| kubectl --context $(KUBE_CONTEXT) apply --server-side --force-conflicts -f -
	kubectl --context $(KUBE_CONTEXT) label crd \
		applications.argoproj.io appprojects.argoproj.io applicationsets.argoproj.io \
		app.kubernetes.io/managed-by=Helm --overwrite
	kubectl --context $(KUBE_CONTEXT) annotate crd \
		applications.argoproj.io appprojects.argoproj.io applicationsets.argoproj.io \
		meta.helm.sh/release-name=$(RELEASE) \
		meta.helm.sh/release-namespace=$(NAMESPACE) --overwrite
	kubectl --context $(KUBE_CONTEXT) wait --for=condition=Established \
		crd/applications.argoproj.io crd/appprojects.argoproj.io crd/applicationsets.argoproj.io \
		--timeout=60s
	helm upgrade --install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--kube-context $(KUBE_CONTEXT) \
		--wait --timeout $(TIMEOUT)

template: ## Render manifests from the vendored chart + values
	helm template $(RELEASE) . --namespace $(NAMESPACE)

vendor: ## Re-pull the upstream argo-cd chart into charts/argo-cd (pin CHART_VERSION)
	rm -rf charts/argo-cd
	helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
	helm repo update argo
	helm pull argo/argo-cd --version $(CHART_VERSION) --untar --untardir charts
