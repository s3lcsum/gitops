#!/usr/bin/env bash
# Cross-platform homelab toolchain setup for Cursor Cloud Agent environments.
#
# macOS : brew-based (preserves the original "vibe MacBook" path).
# Linux : installs the real toolchain needed to work this repo from a cloud VM
#         (OpenTofu, tflint, pre-commit, uv/uvx, kubectl, helm, Hugo).
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
  # iproute2 provides `ip`, which wireguard-up.sh requires to configure wg0.
  sudo apt-get install -y -qq ca-certificates curl gnupg unzip zip python3-pip pipx jq iproute2 wireguard >/dev/null
  export PATH="$HOME/.local/bin:$PATH"

  # uv / uvx (mkdocs material via `make serve/build/lint`)
  command -v uvx >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"

  # pre-commit (verification gate: `pre-commit run --all-files`)
  pipx ensurepath >/dev/null 2>&1 || true
  command -v pre-commit >/dev/null 2>&1 || pipx install pre-commit

  # OpenTofu (pinned via tofu/.opentofu-version; terraform/ is retired)
  TOFU_VERSION="$(cat "$REPO_ROOT/tofu/.opentofu-version" 2>/dev/null || echo 1.12.5)"
  command -v tofu >/dev/null 2>&1 || \
    curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.tar.gz" \
      | sudo tar -xz -C /usr/local/bin tofu

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

  # Hugo extended. Website templates use hugo.Data (>= 0.156.0) and toCSS,
  # which defaults to the LibSass transpiler shipped in the extended edition.
  HUGO_VERSION=0.169.0
  hugo_current="$(hugo version 2>/dev/null || true)"
  case "$hugo_current" in
    *"v${HUGO_VERSION}"*"extended"*) ;;
    *)
      curl -fsSL "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" -o /tmp/hugo.tgz
      tar -xzf /tmp/hugo.tgz -C /tmp hugo
      sudo install -m 0755 /tmp/hugo /usr/local/bin/hugo
      rm -f /tmp/hugo /tmp/hugo.tgz
      ;;
  esac

  echo "linux toolchain ready"
}

case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *) echo "unsupported os: $(uname -s); skipping"; exit 0 ;;
esac
