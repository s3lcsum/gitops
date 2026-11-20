.PHONY: help bootstrap template

KUBE_CONTEXT ?= k8s@lake
TIMEOUT ?= 10m
KUBECTL = kubectl --context "$(KUBE_CONTEXT)"

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Recover Argo CD from the checked-in manifests
	$(KUBECTL) create namespace argocd --dry-run=client -o yaml | $(KUBECTL) apply --server-side -f -
	$(KUBECTL) apply --server-side --force-conflicts -f resources/upstream/crds.yaml
	$(KUBECTL) wait --for=condition=Established \
		crd/applications.argoproj.io crd/appprojects.argoproj.io crd/applicationsets.argoproj.io \
		--timeout=60s
	$(KUBECTL) -n argocd delete job argocd-redis-secret-init --ignore-not-found
	$(KUBECTL) apply --server-side -f resources/upstream/redis-bootstrap.yaml
	$(KUBECTL) -n argocd wait --for=condition=Complete job/argocd-redis-secret-init --timeout="$(TIMEOUT)"
	$(KUBECTL) apply --server-side -f resources/upstream/manifests.yaml
	$(KUBECTL) -n argocd rollout status deployment -l app.kubernetes.io/instance=argocd --timeout="$(TIMEOUT)"
	$(KUBECTL) -n argocd rollout status statefulset/argocd-application-controller --timeout="$(TIMEOUT)"
	$(KUBECTL) apply --server-side -k resources

template: ## Render the Argo CD Kustomization
	kubectl kustomize .
