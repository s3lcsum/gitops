# KIND Clusters

Two single-node KIND clusters running on Podman — one local dev cluster and one on Hermes (the homelab MacBook).

| Cluster | Host | Purpose |
|---------|------|---------|
| `local` | This MacBook | Local dev / experimentation |
| `hermes` | Hermes MacBook | Homelab workloads |

Both expose ports 80 and 443 on the host so Traefik or any ingress controller can bind directly.

## Prerequisites

```bash
brew install kind
# Podman must be running — kind uses it via DOCKER_HOST / KIND_EXPERIMENTAL_PROVIDER
export KIND_EXPERIMENTAL_PROVIDER=podman
```

## Manual cluster management

```bash
# Create
kind create cluster --config kind/clusters/local.yaml
kind create cluster --config kind/clusters/hermes.yaml

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

The `terraform/kind/` module manages both clusters declaratively via the `tehcyx/kind` provider.
Run it locally on each machine — `local` on this MacBook, `hermes` on the Hermes MacBook.
State is stored in GCS (bucket `dominiksiejak-gitops-tfstate`).

```bash
cd terraform/kind
tofu init
tofu apply -var="cluster_target=local"   # on this MacBook
tofu apply -var="cluster_target=hermes"  # on Hermes
```
