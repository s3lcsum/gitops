# KIND Clusters

Two single-node KIND clusters — one local-dev cluster and one on Hermes (the basement homelab MacBook, hostname `vibe`).

| Cluster | Host | Purpose | Runtime |
|---------|------|---------|---------|
| `local` | Primary MacBook | Local dev / experimentation | Podman (`KIND_EXPERIMENTAL_PROVIDER=podman`) when available |
| `hermes` | Hermes MacBook (`vibe`) | Homelab workloads | **Colima** (Intel Mac: Homebrew has no Podman 6 bottle; official 5.8.6 pkg needs sudo) |

Both expose ports 80 and 443 on the host so Traefik can bind via `hostPort`.

On Hermes, `~/.local/bin/kind-hermes-ensure.sh` (LaunchAgent `ai.kind.hermes`) starts Colima and creates/reuses the cluster. Traefik values: `kind/traefik-values.yaml`. Health check:

```bash
curl -H 'Host: whoami.hermes.local' http://127.0.0.1/
```

## Prerequisites

Hermes (this Intel Mac) — Colima is already the KIND Docker provider:

```bash
brew install colima kind kubectl helm
colima start --cpu 4 --memory 8 --disk 50 --runtime docker --vm-type vz
# docker context is `colima`; socket: unix://$HOME/.colima/default/docker.sock
```

Primary MacBook — Podman, when the official installer is available:

```bash
brew install kind
export KIND_EXPERIMENTAL_PROVIDER=podman
```

## Manual cluster management

```bash
# Create
kind create cluster --config kind/clusters/local.yaml
kind create cluster --config kind/clusters/hermes.yaml

# Ingress on hermes (after the cluster exists)
helm repo add traefik https://traefik.github.io/charts
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --values kind/traefik-values.yaml --wait

# Delete
kind delete cluster --name local
kind delete cluster --name hermes

# List
kind get clusters

# Switch context
kubectl config use-context kind-local
kubectl config use-context kind-hermes
```

## Terraform

The `terraform/kind/` module (when present on the branch) manages both clusters via the `tehcyx/kind` provider.
Run it locally on each machine — `local` on the primary MacBook, `hermes` on the Hermes MacBook.
State is stored in GCS (bucket `dominiksiejak-gitops-tfstate`).

```bash
cd terraform/kind
tofu init
tofu apply -var="cluster_target=local"   # on this MacBook
tofu apply -var="cluster_target=hermes"  # on Hermes
```
