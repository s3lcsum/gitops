# KIND Clusters

Two single-node KIND clusters — same recipe (hostPorts 80/443), different names and machines.

| Cluster | Host | Purpose | Runtime |
|---------|------|---------|---------|
| `local` | Primary MacBook | Local dev / experimentation | Podman (`KIND_EXPERIMENTAL_PROVIDER=podman`) when available |
| `vibe` | Basement Intel MacBook (hostname `vibe`) | Homelab workloads on this box | **Colima** (Intel Mac: Homebrew has no Podman 6 bottle; official 5.8.6 pkg needs sudo) |

Both expose ports 80 and 443 on the host so Traefik can bind via `hostPort`.

The cluster name is the machine hostname. It is **not** related to Hermes (the AI gateway that also happens to run on `vibe`). KIND prefixes kubeconfig as `kind-<name>`, so the context is `kind-vibe`.

On `vibe`, `~/.local/bin/kind-vibe-ensure.sh` (LaunchAgent `ai.kind.vibe`) starts Colima and creates/reuses the cluster. Traefik values: `kind/traefik-values.yaml`. Health check:

```bash
curl -H 'Host: whoami.vibe.local' http://127.0.0.1/
```

The OpenTofu `terraform/kind` module was removed. Manage clusters with the `kind` CLI and the YAML under `kind/clusters/`.

## Prerequisites

`vibe` (this Intel Mac) — Colima is already the KIND Docker provider:

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
kind create cluster --config kind/clusters/vibe.yaml

# Ingress on vibe (after the cluster exists)
helm repo add traefik https://traefik.github.io/charts
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --values kind/traefik-values.yaml --wait

# Delete
kind delete cluster --name local
kind delete cluster --name vibe

# List
kind get clusters

# Switch context
kubectl config use-context kind-local
kubectl config use-context kind-vibe
```
