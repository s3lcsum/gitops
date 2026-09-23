.PHONY: help bootstrap vendor template creds oidc encrypt encrypt-creds encrypt-oidc decrypt-check

CHART_VERSION ?= 10.4.0
KUBE_CONTEXT ?= k8s@lake
NAMESPACE ?= argocd
RELEASE ?= argocd
TIMEOUT ?= 10m

CREDS_PLAIN ?= repo-credentials.yaml
CREDS_ENC ?= repo-credentials.enc.yaml
OIDC_PLAIN ?= oidc-client.yaml
OIDC_ENC ?= oidc-client.enc.yaml

# SOPS looks up ~/.config/sops/age/keys.txt by default; override with SOPS_AGE_KEY_FILE.
SOPS ?= sops

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# Decrypt enc → temp file, or use plaintext. Reject placeholders.
# After call, $$tmpdir/secret.yaml is ready; trap cleans on EXIT.
# Args: PLAIN ENC PLACEHOLDER_REGEX
define _materialize_secret
	tmpdir=$$(mktemp -d); \
	trap 'rm -rf '"$$tmpdir" EXIT; \
	if [ -f $(1) ]; then \
		cp $(1) "$$tmpdir/secret.yaml"; \
	elif [ -f $(2) ]; then \
		$(SOPS) -d $(2) > "$$tmpdir/secret.yaml"; \
	else \
		echo "missing $(1) or $(2): copy the .example, fill secrets, then make encrypt"; exit 1; \
	fi; \
	if grep -E -q '$(3)' "$$tmpdir/secret.yaml"; then \
		echo "secret still has a placeholder — refuse apply"; exit 1; \
	fi
endef

bootstrap: ## Install or upgrade Argo CD, then apply GitHub repo creds once
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
	@if kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) get secret argocd-repo-creds-github >/dev/null 2>&1; then \
		exit 0; \
	fi; \
	$(call _materialize_secret,$(CREDS_PLAIN),$(CREDS_ENC),replace-with-github-(pat|username)); \
	kubectl --context $(KUBE_CONTEXT) apply -f "$$tmpdir/secret.yaml"

oidc: ## Patch the Authentik client secret into argocd-secret and restart the server
	@$(call _materialize_secret,$(OIDC_PLAIN),$(OIDC_ENC),replace-with-tofu-output); \
	kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) patch secret argocd-secret --type merge --patch-file "$$tmpdir/secret.yaml"; \
	kubectl --context $(KUBE_CONTEXT) -n $(NAMESPACE) rollout restart deploy/argocd-server

creds: ## Apply or rotate the GitHub repo-creds Secret
	@$(call _materialize_secret,$(CREDS_PLAIN),$(CREDS_ENC),replace-with-github-(pat|username)); \
	kubectl --context $(KUBE_CONTEXT) apply -f "$$tmpdir/secret.yaml"

encrypt: encrypt-creds encrypt-oidc ## Encrypt plaintext → committed *.enc.yaml

encrypt-creds: ## Encrypt repo-credentials.yaml → repo-credentials.enc.yaml
	@test -f $(CREDS_PLAIN) || { echo "missing $(CREDS_PLAIN): copy repo-credentials.yaml.example and set the GitHub PAT"; exit 1; }
	@grep -E -q 'replace-with-github-(pat|username)' $(CREDS_PLAIN) && { echo "$(CREDS_PLAIN) still has a placeholder"; exit 1; } || true
	$(SOPS) encrypt --filename-override $(CREDS_ENC) $(CREDS_PLAIN) > $(CREDS_ENC).tmp
	@mv $(CREDS_ENC).tmp $(CREDS_ENC)
	@echo "wrote $(CREDS_ENC) (safe to commit)"

encrypt-oidc: ## Encrypt oidc-client.yaml → oidc-client.enc.yaml
	@test -f $(OIDC_PLAIN) || { echo "missing $(OIDC_PLAIN): copy oidc-client.yaml.example. Secret is tofu output applications.argocd.client_secret"; exit 1; }
	@grep -q 'replace-with-tofu-output' $(OIDC_PLAIN) && { echo "$(OIDC_PLAIN) still has the placeholder secret"; exit 1; } || true
	$(SOPS) encrypt --filename-override $(OIDC_ENC) $(OIDC_PLAIN) > $(OIDC_ENC).tmp
	@mv $(OIDC_ENC).tmp $(OIDC_ENC)
	@echo "wrote $(OIDC_ENC) (safe to commit)"

decrypt-check: ## Dry-decrypt *.enc.yaml; print keys only (no secret values)
	@found=0; \
	for f in $(CREDS_ENC) $(OIDC_ENC); do \
		[ -f $$f ] || { echo "skip $$f (missing)"; continue; }; \
		found=1; \
		$(SOPS) -d $$f | python3 -c "import yaml,sys; d=yaml.safe_load(sys.stdin); sd=d.get('stringData') or d.get('data') or {}; print('$$f: decrypt_ok keys=' + str(list(sd.keys())))"; \
	done; \
	[ $$found -eq 1 ] || { echo "no *.enc.yaml to check"; exit 1; }

template: ## Render manifests from the vendored chart + values
	helm template $(RELEASE) . --namespace $(NAMESPACE)

vendor: ## Re-pull the upstream argo-cd chart into charts/argo-cd (pin CHART_VERSION)
	rm -rf charts/argo-cd
	helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
	helm repo update argo
	helm pull argo/argo-cd --version $(CHART_VERSION) --untar --untardir charts
