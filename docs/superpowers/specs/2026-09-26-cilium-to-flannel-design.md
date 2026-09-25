# Cilium → Flannel CNI — design

**Date:** 2026-09-26
**Status:** implementing (Cilium removed live; Flannel + kube-proxy GitOps)
**Scope:** Replace Cilium with Flannel + kube-proxy on single-node kubeadm (`k8s@lake`).

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Why | Simpler CNI long-term (no Cilium Hubble/NetworkPolicy/eBPF edge) |
| Downtime | Brief blip + cluster-wide pod restart OK |
| Delivery | Flannel Helm via ApplicationSet; restore kube-proxy |
| Backend | `host-gw` (single node; no VXLAN) |
| Pod CIDR | `10.244.0.0/16` (unchanged) |

## Goals

- Flannel is the only CNI on the node.
- kube-proxy provides ClusterIP/NodePort Services (Cilium kube-proxy replacement gone).
- `kubernetes/cilium/` removed from GitOps; live Cilium DS/operator/CNI conf gone.
- Traefik hostNetwork + CoreDNS keep working after cutover.

## Non-goals

- Multi-node / VXLAN tuning.
- Cilium NetworkPolicy / Hubble feature parity.
- Changing Traefik or AdGuard edge design.

## Architecture

```
Pods ↔ Flannel (host-gw, 10.244.0.0/16)
Services ↔ kube-proxy (iptables or nft)
L7 edge ↔ Traefik hostNetwork (unchanged)
```

## GitOps

```
kubernetes/flannel/
  values.yaml           # chart pin + host-gw + podCidr
  kustomization.yaml    # empty or minimal extras

# DELETE kubernetes/cilium/ (values, gateway-api CRDs tree, kustomization)

AGENTS.md               # CNI = Flannel, not Cilium
```

kube-proxy: prefer kubeadm-managed DaemonSet restored on the node (`kubeadm init phase addon kube-proxy` or equivalent ConfigMap+DS), documented in cutover; optional thin GitOps mirror later if needed.

## Cutover

1. Ensure API reachable; note current pod CIDR.
2. Install/restore **kube-proxy** while Cilium still up (Services stay healthy).
3. Deploy Flannel Helm (Argo app `flannel`); confirm CNI conf present.
4. Remove Cilium from Git + uninstall live release/DS/operator; delete `/etc/cni/net.d/*cilium*`.
5. Restart all non-hostNetwork workloads (and Traefik with Recreate if needed).
6. Smoke: `kubectl get nodes`, CoreDNS lookup, Service ClusterIP, Traefik `:443`.

**Rollback:** re-apply Cilium from git history; remove Flannel CNI conf; restart pods.

## Risks

| Risk | Mitigation |
|------|------------|
| Yank Cilium before kube-proxy | Order: kube-proxy → Flannel → remove Cilium |
| hostNetwork rolling deadlock | Traefik `strategy: Recreate` |
| Stale BPF maps | Node reboot if networking sticky after uninstall |
| ApplicationSet creates `flannel` ns | Chart must install into correct ns (`kube-flannel` or `kube-system`) — pin destination via chart namespace values / fix ApplicationSet if needed |

## Success criteria

- [ ] No Cilium pods/DS/operator
- [ ] Flannel + kube-proxy Running
- [ ] Pods get `10.244.0.0/16` IPs via Flannel
- [ ] CoreDNS + Traefik-k8s HTTPS work

## References

- Current Cilium: `kubernetes/cilium/values.yaml` (`kubeProxyReplacement: true`)
- Traefik hostNetwork: `kubernetes/traefik/values.yaml`
