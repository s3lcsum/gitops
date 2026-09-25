# Cilium → Flannel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or implement inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Cilium with Flannel (host-gw) + kube-proxy on single-node kubeadm.

**Architecture:** ApplicationSet app `flannel` (Helm). kube-proxy ConfigMap+DaemonSet+ClusterRoleBinding in `kubernetes/flannel/resources/` (kube-system). Delete `kubernetes/cilium/`.

**Tech Stack:** flannel/flannel Helm `v0.28.9`, kube-proxy `registry.k8s.io/kube-proxy:v1.37.1`, pod CIDR `10.244.0.0/16`.

**Spec:** `docs/superpowers/specs/2026-09-26-cilium-to-flannel-design.md`

## Global Constraints

- kube-proxy before removing Cilium dataplane
- Flannel backend `host-gw`
- ApplicationSet destination ns = `flannel`
- Brief downtime OK

---

### Task 1: GitOps Flannel + kube-proxy manifests

**Files:**
- Create: `kubernetes/flannel/values.yaml`
- Create: `kubernetes/flannel/kustomization.yaml`
- Create: `kubernetes/flannel/resources/kube-proxy.yaml`

- [ ] Write chart pin + host-gw values
- [ ] Write kube-proxy CM/DS/CRB for clusterCIDR `10.244.0.0/16`, API `https://192.168.89.252:6443`
- [ ] Wire kustomization

### Task 2: Live install kube-proxy + Flannel before yanking Cilium

- [ ] `kubectl apply` kube-proxy resources
- [ ] Deploy Flannel (Argo sync or `helm upgrade --install`)
- [ ] Confirm Flannel DS Ready + CNI conf

### Task 3: Remove Cilium

**Files:**
- Delete: `kubernetes/cilium/`
- Modify: `AGENTS.md`

- [ ] Uninstall live Cilium (Helm/Argo prune)
- [ ] Delete git `kubernetes/cilium/`
- [ ] Restart pods / smoke DNS + Traefik

### Task 4: Docs

- [ ] Spec status implementing/done
- [ ] AGENTS CNI = Flannel
