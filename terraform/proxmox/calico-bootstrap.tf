# Talos uses cluster.network.cni.name: none so Calico can own the CNI (see talos-cluster-network.patch.yaml).
# Until Calico is installed, nodes stay NotReady and nothing (including CoreDNS) can schedule.
# Argo CD cannot install Calico first — bootstrap Calico here after kubeconfig exists.

locals {
  calico_chart_dir = abspath("${path.root}/../../kubernetes/platform/calico")
  # Absolute path so kubectl/helm still see the file after `cd` into the Calico chart dir.
  kubeconfig_for_calico_path = abspath("${path.module}/generated/kubeconfig")
}

resource "local_file" "kubeconfig_for_calico" {
  content         = module.talos_lake.kubeconfig
  filename        = local.kubeconfig_for_calico_path
  file_permission = "0600"

  depends_on = [module.talos_lake]
}

resource "null_resource" "calico_bootstrap" {
  count = var.bootstrap_calico ? 1 : 0

  depends_on = [local_file.kubeconfig_for_calico]

  triggers = {
    kubeconfig_sha = sha256(module.talos_lake.kubeconfig)
    values_sha     = filesha256("${local.calico_chart_dir}/values.yaml")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      export KUBECONFIG="${local.kubeconfig_for_calico_path}"
      kubectl create namespace tigera-operator --dry-run=client -o yaml | kubectl apply -f -
      kubectl label namespace tigera-operator \
        pod-security.kubernetes.io/enforce=privileged \
        pod-security.kubernetes.io/audit=privileged \
        pod-security.kubernetes.io/warn=privileged \
        --overwrite
      CALICO="${local.calico_chart_dir}"
      cd "$CALICO"
      helm dependency build
      helm upgrade --install calico . \
        --kubeconfig "$KUBECONFIG" \
        --namespace tigera-operator \
        --create-namespace \
        --wait \
        --timeout 15m \
        --force-conflicts \
        -f values.yaml
    EOT
  }
}
