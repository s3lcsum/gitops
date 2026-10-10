# Host alert dependencies (anti-domino)

Goal: one root-cause page when infra falls over — not NAS + lake + vibe + k8s worker + workloads all at once.

Status: draft (cascade model not locked). Recommended: **strict tree**.

## Inhibition tree

Arrow = parent firing **inhibits** child (child stays quiet).

```mermaid
flowchart TD
  ROS["RouterOS down<br/><code>mktxp up</code> / <code>probe_success</code>"]

  NAS["NAS down<br/><code>synology up</code> · <code>blackbox-nas</code>"]
  LAKE["lake down<br/><code>node-exporter</code> · <code>node=k8s</code>"]
  VIBE["vibe down<br/><code>job=vibe</code>"]

  NAS_DISK["NAS disk fail / SMART<br/><code>diskStatus</code> ≠ healthy"]
  LAKE_DISK["lake disk low<br/>fs avail on <code>/</code>"]
  K8S_CP["k8s CP / critical workloads<br/>control plane on lake"]
  VIBE_DISK["vibe disk low<br/>APFS <code>/</code>"]
  VIBE_FAN["vibe fans / iSMC<br/>(exists today)"]
  K8S_VIBE["k8s worker vibe<br/><code>node=vibe</code> NotReady"]

  ROS -->|inhibits| NAS
  ROS -->|inhibits| LAKE
  ROS -->|inhibits| VIBE

  NAS -->|inhibits| NAS_DISK
  LAKE -->|inhibits| LAKE_DISK
  LAKE -->|inhibits| K8S_CP
  VIBE -->|inhibits| VIBE_DISK
  VIBE -->|inhibits| VIBE_FAN
  VIBE -->|inhibits| K8S_VIBE

  classDef root fill:#fecaca,stroke:#ef4444,color:#7f1d1d
  classDef host fill:#fed7aa,stroke:#f97316,color:#7c2d12
  classDef leaf fill:#e2e8f0,stroke:#94a3b8,color:#334155

  class ROS root
  class NAS,LAKE,VIBE host
  class NAS_DISK,LAKE_DISK,K8S_CP,VIBE_DISK,VIBE_FAN,K8S_VIBE leaf
```

## Anti-domino rules

1. **Highest ancestor wins.** RouterOS dies → page RouterOS only. NAS / lake / vibe host-down stay silent.
2. **Host silences own symptoms.** Host down → no disk-low / fans / SMART / that host’s k8s-node alerts.
3. **Topology facts**
   - lake down → k8s control plane down (and often monitoring on lake too).
   - vibe down → k8s worker `node=vibe` down.
4. **Symptoms only when host still up.** Disk / fans need live scrapes from that host.

## Cascade model options

| | Model | Behavior |
|---|---|---|
| **A** | Strict tree (recommended) | Full diagram above. One page per outage root. |
| **B** | Host-only inhibit | No RouterOS umbrella. Hosts silence own symptoms only. RouterOS + hosts can all fire. |
| **C** | Page roots only | Phone only host-down + disk-fail. Fans + disk-low = soft notify. |

## Signals (existing scrape jobs)

| Alert | Signal |
|---|---|
| RouterOS down | `up{job="mktxp"}` and/or `probe_success{job="blackbox-router"}` |
| NAS down | `up{job="synology"}` and/or `probe_success{job="blackbox-nas"}` |
| NAS disk fail | `diskStatus` / `diskHealthStatus` (SNMP) |
| lake down | `up{job="node-exporter",node="k8s"}` |
| lake disk low | `node_filesystem_avail_bytes` on `/` |
| vibe down | `up{job="vibe"}` |
| vibe disk low | `node_filesystem_*{job="vibe",mountpoint="/"}` |
| vibe fans | existing `vibe-ismc` rules (duty &gt; 60%, iSMC silent) |
| k8s worker vibe | inhibit when vibe host down (no separate page if parent fires) |
| k8s CP / workloads | existing critical-workload rules; inhibit when lake (or RouterOS) down |

## Note on monitoring locality

lake hosts VictoriaMetrics / exporters. lake hard-down → many scrapes go dark. Prefer external or path-independent probes where possible for RouterOS + NAS UI (`blackbox-*`). Treat scrape `up==0` carefully when the scraper itself may be dead.
