#!/usr/bin/env bash
# Cross-platform homelab toolchain setup for Cursor Cloud Agent environments.
#
# macOS : brew-based (preserves the original "vibe MacBook" path).
# Linux : installs the real toolchain needed to work this repo from a cloud VM
#         (OpenTofu, Terragrunt, tflint, pre-commit, uv/uvx, kubectl, helm).
#
# Idempotent: every step guards on `command -v` so re-runs are cheap.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

install_macos() {
  command -v brew >/dev/null 2>&1 || { echo "brew not found; skipping macos setup"; exit 0; }
  brew list --formula helm          >/dev/null 2>&1 || brew install helm
  brew list --formula kubernetes-cli >/dev/null 2>&1 || brew install kubernetes-cli
  brew list --formula wireguard-tools >/dev/null 2>&1 || brew install wireguard-tools
  echo "macos toolchain ready"
}

install_linux() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl gnupg unzip zip python3-pip pipx jq wireguard iproute2 dnsutils >/dev/null
  export PATH="$HOME/.local/bin:$PATH"

  # uv / uvx (mkdocs material via `make serve/build/lint`)
  command -v uvx >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"

  # pre-commit (verification gate: `pre-commit run --all-files`)
  pipx ensurepath >/dev/null 2>&1 || true
  command -v pre-commit >/dev/null 2>&1 || pipx install pre-commit

  # OpenTofu pin lives in tofu/.opentofu-version (AGENTS.md). Fallback matches the current pin.
  if [ -f "$REPO_ROOT/tofu/.opentofu-version" ]; then
    TOFU_VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/tofu/.opentofu-version")"
  else
    TOFU_VERSION=1.12.5
  fi
  command -v tofu >/dev/null 2>&1 || \
    curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
      | sudo tar -xz -C /usr/local/bin tofu

  # Terragrunt (`make -C tofu plan`). Pinned; the Makefile calls `terragrunt run`.
  command -v terragrunt >/dev/null 2>&1 || {
    TG_VERSION=1.2.1
    curl -fsSL "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VERSION}/terragrunt_linux_amd64" -o /tmp/terragrunt
    sudo install -m 0755 /tmp/terragrunt /usr/local/bin/terragrunt
    rm -f /tmp/terragrunt
  }

  # tflint (pre-commit terraform_tflint hook)
  command -v tflint >/dev/null 2>&1 || {
    TFLINT_VERSION=v0.54.0
    curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip" -o /tmp/tflint.zip
    unzip -o /tmp/tflint.zip -d /tmp/tflint >/dev/null
    sudo install -m 0755 /tmp/tflint/tflint /usr/local/bin/tflint
    rm -rf /tmp/tflint /tmp/tflint.zip
  }

  # kubectl
  command -v kubectl >/dev/null 2>&1 || {
    KUBECTL_VERSION="$(curl -sL https://dl.k8s.io/release/stable.txt)"
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /tmp/kubectl
    sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm -f /tmp/kubectl
  }

  # helm
  command -v helm >/dev/null 2>&1 || {
    HELM_VERSION=v3.16.3
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o /tmp/helm.tgz
    tar -xzf /tmp/helm.tgz -C /tmp linux-amd64/helm >/dev/null
    sudo install -m 0755 /tmp/linux-amd64/helm /usr/local/bin/helm
    rm -rf /tmp/helm.tgz /tmp/linux-amd64
  }

  # OpenBao CLI matches the cluster (2.7.2). The real binary lives in libexec;
  # /usr/local/bin/bao is a wrapper that sets the homelab address and token.
  sudo mkdir -p /usr/local/libexec
  BAO_VERSION=2.7.2
  if ! /usr/local/libexec/bao version 2>/dev/null | grep -q "v${BAO_VERSION}"; then
    curl -fsSL "https://github.com/openbao/openbao/releases/download/v${BAO_VERSION}/openbao_${BAO_VERSION}_linux_amd64.tar.gz" -o /tmp/bao.tgz
    tar -xzf /tmp/bao.tgz -C /tmp bao
    sudo install -m 0755 /tmp/bao /usr/local/libexec/bao
    rm -f /tmp/bao /tmp/bao.tgz
  fi
  sudo install -m 0755 "$SCRIPT_DIR/bao-wrapper.sh" /usr/local/bin/bao

  # Argo CD CLI matches the chart app version (v3.5.6).
  ARGOCD_VERSION=v3.5.6
  if ! argocd version --client --short 2>/dev/null | grep -q "v3.5.6"; then
    curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" -o /tmp/argocd
    sudo install -m 0755 /tmp/argocd /usr/local/bin/argocd
    rm -f /tmp/argocd
  fi

  # uv and pipx land in ~/.local/bin. Agent shells use the default PATH, which
  # does not include that directory, so expose the binaries from /usr/local/bin.
  for tool in uv uvx pre-commit; do
    if [ -x "$HOME/.local/bin/$tool" ]; then
      sudo ln -sfn "$HOME/.local/bin/$tool" "/usr/local/bin/$tool"
    fi
  done

  echo "linux toolchain ready"
}

case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *) echo "unsupported os: $(uname -s); skipping"; exit 0 ;;
esac
