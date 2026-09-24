# Traefik-in-k8s Edge Implementation Plan

> **SUPERSEDED** by design `docs/superpowers/specs/2026-09-24-cilium-cni-traefik-ingress-design.md`. Do not execute this plan as written: Portainer Traefik stays as origin (allowlist HTTPS hop), not retired; compose backends go through Portainer Traefik, not direct EndpointSlices to every LAN IP.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Cilium Gateway L7 and Portainer Traefik with one Traefik Helm edge in Kubernetes on `192.168.89.252` hostNetwork `:80/:443`, with Authentik forward-auth and CrowdSec day-1, routes as GitOps IngressRoutes.

**Architecture:** Argo ApplicationSet app `traefik` (Helm chart + `kubernetes/traefik/resources`). Cilium stays CNI-only. Compose workloads stay on Portainer; backends are `Service`+`EndpointSlice` to LAN IPs. Wildcard TLS via cert-manager Certificate in `traefik` namespace. CrowdSec LAPI stays on Portainer (`.253`); Traefik plugin bounces to it.

**Tech Stack:** Traefik Helm chart `41.6.0` (app `v3.7.13`), Traefik CRDs (IngressRoute/Middleware/ServersTransport), cert-manager, External Secrets (CrowdSec LAPI key), Cilium CNI, existing Authentik outpost on `.253`.

**Spec:** `docs/superpowers/specs/2026-09-24-traefik-k8s-edge-design.md`

## Global Constraints

- Destination DNS: AdGuard `*.dominiksiejak.pl` → `192.168.89.252` after cutover.
- Listen: hostNetwork `:80` (redirect) + `:443` on the single lake node.
- Providers: `kubernetesCRD` only (no Docker provider).
- Auth day-1: CrowdSec bouncer plugin **and** Authentik forward-auth Middleware.
- Pin Helm chart version exactly in `values.yaml` (`repoURL` / `chart` / `version` ApplicationSet pin keys).
- Do not introduce privileged iptables “fix” DaemonSets for TPROXY.
- Keep `bpf.tproxy: false` on Cilium while validating hostNetwork binds.
- `hostNetwork` cannot share `:80/:443` with Cilium Gateway — Gateway must be scaled down / deleted before Traefik binds those ports.
- Prune stays off on ApplicationSet children unless explicitly changed later.
- Domain pattern: `{service}.dominiksiejak.pl`.

## File map

| Path | Responsibility |
|------|----------------|
| `kubernetes/traefik/values.yaml` | Chart pin + Traefik Helm overrides (hostNetwork, ports, plugins, providers) |
| `kubernetes/traefik/kustomization.yaml` | Lists `resources/` |
| `kubernetes/traefik/resources/certificate.yaml` | Wildcard Certificate → Secret `dominiksiejak-pl-tls` in `traefik` ns |
| `kubernetes/traefik/resources/externalsecret-crowdsec.yaml` | LAPI key into Traefik env/Secret |
| `kubernetes/traefik/resources/middlewares/*.yaml` | secure-headers, crowdsec, authentik, lan-only, rate-limit, … |
| `kubernetes/traefik/resources/backends/*.yaml` | Services + EndpointSlices for `.253` / LAN |
| `kubernetes/traefik/resources/routes/*.yaml` | IngressRoutes |
| `kubernetes/traefik/resources/servers-transports.yaml` | insecure / CA transports for HTTPS origins |
| `kubernetes/cert-manager/resources/certificate.yaml` | Stop issuing into `cilium` ns (delete or retarget after cutover) |
| `kubernetes/cilium/resources/edge.yaml` + `proxies/*` | Remove Gateway/HTTPRoute/BackendTLSPolicy after cutover |
| `stacks/traefik/` | Retire compose Traefik (+ keep CrowdSec LAPI containers if split) |
| `terraform/portainer/locals.tf` | Drop or shrink traefik stack entry when drained |
| `scripts/auth_classification.yaml` | Source of auth class per host (restore if missing from tree) |
| `AGENTS.md` / `README.md` | Edge = Traefik-in-k8s |

---

### Task 1: Scaffold `kubernetes/traefik` Argo app (ClusterIP smoke, no hostNetwork yet)

**Files:**
- Create: `kubernetes/traefik/values.yaml`
- Create: `kubernetes/traefik/kustomization.yaml`
- Create: `kubernetes/traefik/resources/.gitkeep`

**Interfaces:**
- Consumes: ApplicationSet generator `kubernetes/*/values.yaml`
- Produces: Argo Application `traefik` syncing Helm release `traefik` into namespace `traefik`

- [ ] **Step 1: Write chart pin values (ClusterIP first — do not steal :80/:443 yet)**

```yaml
# kubernetes/traefik/values.yaml
repoURL: https://traefik.github.io/charts
chart: traefik
version: 41.6.0

# Overrides for Traefik Helm 41.6.0 (app v3.7.13).
# Phase 1: ClusterIP only. hostNetwork enabled in Task 5 after Cilium Gateway is down.
deployment:
  replicas: 1
hostNetwork: false
service:
  enabled: true
  type: ClusterIP
ports:
  web:
    port: 8000
    expose:
      default: true
    redirections:
      entryPoint:
        to: websecure
        scheme: https
        permanent: true
  websecure:
    port: 8443
    expose:
      default: true
    tls:
      enabled: true
providers:
  kubernetesCRD:
    enabled: true
    allowCrossNamespace: true
    allowExternalNameServices: true
  kubernetesIngress:
    enabled: false
ingressRoute:
  dashboard:
    enabled: false
experimental:
  plugins:
    crowdsec-bouncer-traefik-plugin:
      moduleName: github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin
      version: v1.4.4
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
resources:
  requests:
    cpu: 50m
    memory: 128Mi
logs:
  general:
    level: INFO
  access:
    enabled: true
```

- [ ] **Step 2: Add empty kustomization**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
```

- [ ] **Step 3: Commit and push; wait for ApplicationSet**

```bash
git add kubernetes/traefik/
git commit -m "Add Traefik Helm scaffold as ClusterIP Argo app."
git push
kubectl --context k8s@lake -n argocd get application traefik
kubectl --context k8s@lake -n traefik get deploy,pods,svc
```

Expected: Application `traefik` Healthy/Synced; Deployment `traefik` Ready; Service ClusterIP present.

- [ ] **Step 4: Port-forward smoke**

```bash
kubectl --context k8s@lake -n traefik port-forward svc/traefik 8443:443
# expect connection; no routes yet → 404 from Traefik is OK
curl -vk https://127.0.0.1:8443/ | head
```

Expected: TLS handshake from Traefik (default cert OK for now).

---

### Task 2: Wildcard Certificate in `traefik` namespace

**Files:**
- Create: `kubernetes/traefik/resources/certificate.yaml`
- Modify: `kubernetes/traefik/kustomization.yaml`

**Interfaces:**
- Consumes: ClusterIssuer `letsencrypt` (cert-manager app)
- Produces: Secret `traefik/dominiksiejak-pl-tls`

- [ ] **Step 1: Add Certificate**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: dominiksiejak-pl
  namespace: traefik
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  secretName: dominiksiejak-pl-tls
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
  dnsNames:
    - dominiksiejak.pl
    - "*.dominiksiejak.pl"
```

- [ ] **Step 2: Wire kustomization**

```yaml
resources:
  - resources/certificate.yaml
```

- [ ] **Step 3: Commit, sync, verify Secret**

```bash
git add kubernetes/traefik/
git commit -m "Issue wildcard TLS Secret into traefik namespace."
git push
kubectl --context k8s@lake -n traefik get certificate,secret dominiksiejak-pl-tls
```

Expected: Certificate Ready; Secret has `tls.crt` / `tls.key`.

---

### Task 3: Core Middlewares + Authentik + CrowdSec plugin wiring

**Files:**
- Create: `kubernetes/traefik/resources/middlewares/secure-headers.yaml`
- Create: `kubernetes/traefik/resources/middlewares/lan-only.yaml`
- Create: `kubernetes/traefik/resources/middlewares/authentik.yaml`
- Create: `kubernetes/traefik/resources/middlewares/crowdsec.yaml`
- Create: `kubernetes/traefik/resources/backends/authentik.yaml`
- Create: `kubernetes/traefik/resources/backends/crowdsec-lapi.yaml`
- Create: `kubernetes/traefik/resources/externalsecret-crowdsec.yaml`
- Modify: `kubernetes/traefik/values.yaml` (env from Secret for LAPI key)
- Modify: `kubernetes/traefik/kustomization.yaml`

**Interfaces:**
- Consumes: Authentik on `192.168.89.253:9000` (outpost path); CrowdSec LAPI on `192.168.89.253:8080` (confirm published port on Portainer host)
- Produces: Middleware names `secure-headers`, `lan-only`, `authentik`, `crowdsec-bouncer` in `traefik` ns

- [ ] **Step 1: Backend for Authentik forward-auth**

```yaml
# kubernetes/traefik/resources/backends/authentik.yaml
apiVersion: v1
kind: Service
metadata:
  name: authentik-forwardauth
  namespace: traefik
spec:
  ports:
    - name: http
      port: 9000
      targetPort: 9000
---
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: authentik-forwardauth
  namespace: traefik
  labels:
    kubernetes.io/service-name: authentik-forwardauth
addressType: IPv4
ports:
  - name: http
    port: 9000
    protocol: TCP
endpoints:
  - addresses:
      - 192.168.89.253
```

- [ ] **Step 2: Authentik Middleware (port from compose labels)**

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: authentik
  namespace: traefik
spec:
  forwardAuth:
    address: http://authentik-forwardauth.traefik.svc:9000/outpost.goauthentik.io/auth/traefik
    trustForwardHeader: false
    authResponseHeaders:
      - X-authentik-username
      - X-authentik-groups
      - X-authentik-entitlements
      - X-authentik-email
      - X-authentik-name
      - X-authentik-uid
      - X-authentik-jwt
      - X-authentik-meta-jwks
      - X-authentik-meta-outpost
      - X-authentik-meta-provider
      - X-authentik-meta-app
      - X-authentik-meta-version
```

- [ ] **Step 3: CrowdSec LAPI backend + ExternalSecret**

Confirm LAPI listen address on Portainer (`docker inspect crowdsec` / compose ports). Default plan assumes host `192.168.89.253` port `8080`.

```yaml
# backends/crowdsec-lapi.yaml — Service+EndpointSlice to 192.168.89.253:8080
# externalsecret-crowdsec.yaml — 1Password item (tag ArgoCD External Secrets Operator)
#   target Secret key: CROWDSEC_API_KEY
#   empty template.metadata labels/annotations (same pattern as cert-manager Cloudflare ES)
```

Add to Traefik values:

```yaml
env:
  - name: CROWDSEC_API_KEY
    valueFrom:
      secretKeyRef:
        name: crowdsec-lapi
        key: CROWDSEC_API_KEY
```

CrowdSec Middleware CRD using plugin (LAPI URL `http://crowdsec-lapi.traefik.svc:8080`), trusted IPs matching `stacks/traefik/dynamic.yaml` (`192.168.89.0/24`, docker ranges).

- [ ] **Step 4: secure-headers + lan-only Middlewares**

Port fields from `stacks/traefik/dynamic.yaml` (`secure-headers`, `lan-only`) into Middleware CRDs.

- [ ] **Step 5: Commit, sync, verify CRDs**

```bash
kubectl --context k8s@lake -n traefik get middleware
kubectl --context k8s@lake -n traefik get endpointslices
```

Expected: four middlewares; EndpointSlices Ready.

---

### Task 4: Pilot routes — `argocd` + one compose host (`homepage`)

**Files:**
- Create: `kubernetes/traefik/resources/backends/argocd.yaml` (optional if same-cluster Service DNS works cross-ns)
- Create: `kubernetes/traefik/resources/backends/homepage.yaml` (EndpointSlice → `.253:443` or published HTTP port)
- Create: `kubernetes/traefik/resources/routes/argocd.yaml`
- Create: `kubernetes/traefik/resources/routes/homepage.yaml`
- Create: `kubernetes/traefik/resources/servers-transports.yaml` (if homepage/Traefik origin needs TLS skip)

**Interfaces:**
- Consumes: Middlewares from Task 3; Secret `dominiksiejak-pl-tls`
- Produces: Working IngressRoutes testable via `curl --resolve`

- [ ] **Step 1: argocd IngressRoute**

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd
  namespace: traefik
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`argocd.dominiksiejak.pl`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
        - name: secure-headers
      services:
        - name: argocd-server
          namespace: argocd
          port: 80
  tls:
    secretName: dominiksiejak-pl-tls
```

(Adjust middleware list to match auth class for argocd — OIDC native at app; typically **no** forward-auth at edge.)

- [ ] **Step 2: homepage backend + IngressRoute**

EndpointSlice to Portainer Traefik or directly to homepage container published port on `.253`. Prefer hitting current Traefik on `.253:443` with Host header only during pilot if easier; final state should target the compose service port on the `proxy` network via host-published port or LAN IP.

- [ ] **Step 3: Test via port-forward + resolve**

```bash
kubectl --context k8s@lake -n traefik port-forward svc/traefik 8443:443
curl -vk --resolve argocd.dominiksiejak.pl:8443:127.0.0.1 https://argocd.dominiksiejak.pl:8443/
curl -vk --resolve homepage.dominiksiejak.pl:8443:127.0.0.1 https://homepage.dominiksiejak.pl:8443/
```

Expected: HTTP 200/302 from real apps; Authentik/CrowdSec behave per class.

- [ ] **Step 4: Commit**

```bash
git commit -m "Add pilot IngressRoutes for argocd and homepage."
```

---

### Task 5: Cut over hostNetwork `:80/:443` (replace Cilium Gateway bind)

**Files:**
- Modify: `kubernetes/traefik/values.yaml` (`hostNetwork: true`, ports 80/443)
- Modify: `kubernetes/cilium/resources/edge.yaml` — remove Gateway + https-redirect HTTPRoute (or delete file content)
- Modify: `kubernetes/cilium/kustomization.yaml` — drop edge Gateway resources when empty
- Modify: AdGuard live rewrites only after Traefik is listening (Task 6)

**Interfaces:**
- Consumes: Pilot routes from Task 4
- Produces: Traefik owning host `:80/:443` on `.252`

- [ ] **Step 1: Scale down / remove Cilium Gateway first**

```bash
kubectl --context k8s@lake -n cilium delete gateway cilium --wait=true
# confirm nothing listens :443 on host
ssh lake 'ss -lntp | rg ":443|:80"'   # or local equivalent on node
```

Expected: ports free (or only kube leftovers).

- [ ] **Step 2: Enable hostNetwork in values**

```yaml
hostNetwork: true
deployment:
  replicas: 1
service:
  enabled: false   # hostNetwork; no ClusterIP needed for dataplane
ports:
  web:
    port: 80
    hostPort: 80
  websecure:
    port: 443
    hostPort: 443
    tls:
      enabled: true
```

(Confirm chart 41.x `expose` / `hostPort` schema against chart values before apply — adjust field names to chart.)

- [ ] **Step 3: Commit Traefik values + remove Gateway manifests; sync**

```bash
kubectl --context k8s@lake -n traefik get pods -o wide
curl -vk --resolve argocd.dominiksiejak.pl:443:192.168.89.252 https://argocd.dominiksiejak.pl/
```

Expected: SYN completes; TLS with wildcard cert; argocd UI loads.

- [ ] **Step 4: If SYN_RECV / hang — do not add iptables DaemonSet**

Revert Traefik to ClusterIP, restore Gateway from git, file Cilium issue / reassess `bpf` knobs. Stop the cutover.

---

### Task 6: Bulk IngressRoutes + backends; AdGuard flip

**Files:**
- Create: `kubernetes/traefik/resources/routes/*.yaml` (all hosts)
- Create: `kubernetes/traefik/resources/backends/*.yaml`
- Modify: `stacks/adguard/conf/AdGuardHome.yaml.example` (static list → `.252` if not already)
- Modify / restore: `scripts/auth_classification.yaml` if absent from tree
- Optional: `scripts/gen_traefik_routes.py` one-shot from compose labels + classification

**Interfaces:**
- Consumes: Middleware naming from Task 3; auth classes
- Produces: Full host coverage on Traefik-in-k8s

- [ ] **Step 1: Inventory hosts**

Sources:

- Traefik Docker labels in `stacks/*/compose.yaml`
- `stacks/traefik/dynamic.yaml` routers
- Cilium HTTPRoute hostnames under `kubernetes/cilium/resources/proxies/`

- [ ] **Step 2: Generate or hand-write IngressRoutes**

Chain mapping:

| auth class | middlewares (order) |
|------------|---------------------|
| `forward-auth` | `crowdsec-bouncer`, `secure-headers`, `authentik` |
| `native-oidc` | `crowdsec-bouncer`, `secure-headers` |
| `public` | `crowdsec-bouncer`, `secure-headers` |
| `lan-only` | `crowdsec-bouncer`, `secure-headers`, `lan-only` |

Special cases from `dynamic.yaml`: `n8n` webhook path (priority, strip-authentik), `opencode` upstream Basic, LAN HTTPS origins (ServersTransport).

- [ ] **Step 3: Apply AdGuard static rewrites → `192.168.89.252`**

Keep per-host static list (no wildcard-only). Sync AdGuard config to host (`apply portainer` workflow).

- [ ] **Step 4: Smoke matrix**

```bash
for h in argocd homepage auth grafana nas proxmox; do
  curl -sS -o /dev/null -w "%{http_code} $h\n" --resolve ${h}.dominiksiejak.pl:443:192.168.89.252 \
    https://${h}.dominiksiejak.pl/
done
```

Expected: 200/302/401 as appropriate; no connection timeouts.

- [ ] **Step 5: Commit**

```bash
git commit -m "Route all edge hosts through Traefik-in-k8s IngressRoutes."
```

---

### Task 7: Drain Portainer Traefik; delete Cilium L7 leftovers

**Files:**
- Modify: `stacks/traefik/compose.yaml` — remove Traefik container; **keep** CrowdSec LAPI (+ acquis) if still used
- Modify: `terraform/portainer/locals.tf` / stack wiring if stack shrinks
- Delete or empty: Cilium `resources/edge.yaml` Gateway bits, proxy HTTPRoutes/BackendTLSPolicies/CA ConfigMaps only used for Gateway
- Modify: `kubernetes/cert-manager/resources/certificate.yaml` — remove `cilium` Certificate once unused
- Modify: `AGENTS.md`, `README.md` — edge docs

- [ ] **Step 1: Stop Portainer Traefik process**

Ensure no listeners on `.253:80/:443` (or leave Traefik up but unused until confident, then remove).

```bash
# after compose change + portainer apply
ssh portainer 'docker ps --format "{{.Names}}" | rg traefik'
```

Expected: no `traefik` container (CrowdSec may remain).

- [ ] **Step 2: Remove Cilium Gateway-related manifests from git; sync**

- [ ] **Step 3: Update docs**

AGENTS.md Networking + Architecture: edge = Traefik-in-k8s on `.252`; Cilium CNI-only.

- [ ] **Step 4: Consistency**

```bash
make consistency
```

Expected: exit 0 (or only known report-only gaps). Fix auth_classification / blackbox / homepage as needed.

- [ ] **Step 5: Final commit**

```bash
git commit -m "Retire Portainer Traefik and Cilium Gateway edge path."
```

---

### Task 8: Verification checklist (done means done)

- [ ] **Step 1: Success criteria from spec**

- [ ] All classified hosts served by Traefik-in-k8s on `.252`
- [ ] Portainer Traefik not in request path
- [ ] No Cilium Gateway / HTTPRoute / BackendTLSPolicy required for edge HTTP
- [ ] Authentik forward-auth works on a `forward-auth` host
- [ ] CrowdSec bounce works (test with known banned IP or LAPI decision)
- [ ] `make consistency` green
- [ ] argocd + homepage + one LAN origin (nas or proxmox) healthy over HTTPS

- [ ] **Step 2: Document rollback in README changelog** (`### DD.MM.YYYY`)

---

## Spec coverage self-review

| Spec item | Task |
|-----------|------|
| Traefik Helm via Argo | Task 1 |
| hostNetwork `.252` :80/:443 | Task 5 |
| Static IngressRoutes | Tasks 4, 6 |
| Authentik + CrowdSec day-1 | Task 3 |
| Wildcard TLS | Task 2 |
| Service+EndpointSlice backends | Tasks 3, 4, 6 |
| Phased cutover / Gateway removed before bind | Task 5 |
| Drain Portainer Traefik | Task 7 |
| Cilium CNI-only | Tasks 5, 7 |
| consistency / docs | Tasks 6–8 |
| No iptables workaround DS | Task 5 step 4 |

## Placeholder scan

No TBD/TODO left in steps. Chart field names for `ports.*.expose` must be confirmed against chart `41.6.0` values during Task 1 (schema drift is the only intentional “verify against chart” note).
