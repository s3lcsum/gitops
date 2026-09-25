# Kyverno + label policies + Policy Reporter — design

**Date:** 2026-09-26
**Status:** implementing

**Scope:** Install Kyverno on lake via ApplicationSet; Audit-mode CEL ValidatingPolicy requiring recommended `app.kubernetes.io/*` labels on Pods; Policy Reporter UI at `policy-reporter.dominiksiejak.pl` behind Authentik forward-auth.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Failure mode | `Audit` only (no Admit deny) |
| Required labels | `app.kubernetes.io/name`, `instance`, `part-of`, `managed-by` (non-empty) |
| Match | Pods CREATE/UPDATE + background scan; cluster-wide, no policy ns exclusions |
| Policy API | `policies.kyverno.io/v1` ValidatingPolicy (legacy `ClusterPolicy` deprecated in v1.19) |
| Label existing / kube-system | Out of scope — reports show debt later |
| Policy Reporter | UI + Kyverno plugin; Traefik `Host(policy-reporter.dominiksiejak.pl)` + forward-auth |

## Goals

- Kyverno admission + background + reports controllers on single-node lake.
- One Audit ValidatingPolicy for recommended labels.
- Policy Reporter UI shows PolicyReport / ValidatingPolicy results.
- Edge auth matches other Traefik-k8s forward-auth hosts.

## Non-goals

- Enforce mode, PSS/`kyverno-policies` chart, labeling live kube-system/static pods.
- Policy Reporter native OIDC (edge Authentik enough).
- Grafana boards.

## Architecture

```
ApplicationSet
  ├─ kubernetes/kyverno/          → Helm kyverno 3.9.1 (app v1.19.1) + ValidatingPolicy
  └─ kubernetes/policy-reporter/ → Helm policy-reporter 3.10.0 (UI + kyverno plugin)
         └─ IngressRoute Host(policy-reporter.dominiksiejak.pl)
              → crowdsec + secure-headers + authentik → policy-reporter-ui:8080
```

Webhook still skips `kyverno` namespace (chart default, operability). Separate from “no policy exclusions.”

## GitOps layout

```
kubernetes/kyverno/
  values.yaml                 # chart pin + lake replicas/tolerations
  kustomization.yaml
  resources/require-labels.yaml

kubernetes/policy-reporter/
  values.yaml                 # chart pin; ui + plugin.kyverno
  kustomization.yaml
  resources/ingressroute.yaml

scripts/auth_classification.yaml   # kyverno → forward-auth
terraform/authentik/locals.tf      # proxy_applications.policy-reporter
```

Argo CD already excludes `kyverno.io` / `reports.kyverno.io` / `wgpolicyk8s.io` report kinds from watch — no change.

## Deploy notes

1. Merge to `main` → ApplicationSet creates `kyverno` + `policy-reporter` Applications.
2. `make apply` in `terraform/authentik` so Embedded Outpost gets the new proxy provider.
3. Smoke: controllers Ready; `kubectl get validatingpolicy`; UI at `https://policy-reporter.dominiksiejak.pl`.
