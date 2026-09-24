.PHONY: help bootstrap template

REPO_NAME ?= argo
REPO_URL ?= https://argoproj.github.io/argo-helm
CHART ?= argo-cd
CHART_VERSION ?= 10.4.0
KUBE_CONTEXT ?= k8s@lake
NAMESPACE ?= argocd
RELEASE ?= argocd
TIMEOUT ?= 10m

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

repo: ## Add the upstream chart repo
	helm repo add $(REPO_NAME) $(REPO_URL) >/dev/null 2>&1 || true
	helm repo update $(REPO_NAME)

bootstrap: repo ## Install or upgrade Argo CD from the remote chart, then apply resources/
	helm template $(RELEASE) $(REPO_NAME)/$(CHART) --version $(CHART_VERSION) --namespace $(NAMESPACE) -f values.yaml \
		-s templates/crds/crd-application.yaml \
		-s templates/crds/crd-appproject.yaml \
		-s templates/crds/crd-applicationset.yaml \
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
	helm upgrade --install $(RELEASE) $(REPO_NAME)/$(CHART) --version $(CHART_VERSION) \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--kube-context $(KUBE_CONTEXT) \
		-f values.yaml \
		--wait --timeout $(TIMEOUT)
	kubectl --context $(KUBE_CONTEXT) apply -k resources

template: repo ## Render the remote chart and the Kustomize resources
	helm template $(RELEASE) $(REPO_NAME)/$(CHART) --version $(CHART_VERSION) --namespace $(NAMESPACE) -f values.yaml
	kubectl kustomize resources
