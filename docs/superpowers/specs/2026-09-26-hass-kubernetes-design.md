# Home Assistant on Kubernetes — design

**Date:** 2026-09-26
**Status:** approved

**Scope:** Move the whole Portainer `hass` stack (Home Assistant, Mosquitto, Zigbee2MQTT Wi-Fi, Zigbee2MQTT USB, HA Time Machine) onto the lake kubeadm node. Recorder history moves to CloudNativePG.

## Decisions (locked)

| Topic | Choice |
|-------|--------|
| Scope | All five workloads. USB Zigbee stick moves to the lake node. |
| Recorder | Dump/restore `homeassistant` into CloudNativePG `Cluster/postgres`. |
| LAN reach | `hostNetwork` for Home Assistant and Mosquitto on `192.168.89.252`. |
| Zigbee + Time Machine | Pod network. MQTT at `192.168.89.252:1883`. |
| GitOps shape | Kustomize Application, CoreDNS-style. Not an ApplicationSet Helm child. |
| Config disk | hostPath `/var/lib/hass` on the lake node (rsync from Portainer). |
| Docker socket | Not mounted. |

## Context

The stack runs on the Portainer LXC (`192.168.89.253`) via `stacks/hass/compose.yaml`. Home Assistant and Mosquitto use the host network so discovery and the split MQTT listeners work. Zigbee2MQTT USB takes `/dev/ttyUSB0`. Config, media, Zigbee data, and the Mosquitto passwd file live under `/var/lib/hass`. The recorder database `homeassistant` is on compose Postgres, which listens on `127.0.0.1:5432` only.

The cluster is one kubeadm node, `192.168.89.252`, Flannel host-gw, control-plane taint. Traefik-k8s is already `hostNetwork` on `:80` and `:443`. CloudNativePG `Cluster/postgres` is in namespace `cloudnative-pg`. There is no NFS StorageClass. The ApplicationSet only accepts a Helm chart (`repoURL` / `chart` / `version` in `values.yaml`).

## Goals

- Run the five workloads from `kubernetes/hass`, synced by an Argo CD Application.
- Keep the public hostnames: `hass`, `zigbee2mqtt-wifi`, `zigbee2mqtt-usb`, `hass-timemachine`.
- Keep auth classes: `hass` native-OIDC, the other three forward-auth.
- Serve those hosts from in-cluster IngressRoutes instead of the Portainer hop.
- Restore recorder history into CloudNativePG before Home Assistant starts.
- Remove the compose stack from `terraform/portainer` after the node is serving.

## Non-goals

- Macvlan or a second LAN address.
- Migrating any other compose stack.
- NAS NFS or Barman backups.
- Rebuilding Zigbee networks. Coordinator data directories move as-is.
- Changing Authentik application slugs or launch URLs.
- Mounting a container runtime socket into Home Assistant.

## Architecture

```
Argo CD Application hass
  kubernetes/hass  (Kustomize)
    ├─ namespace hass
    │    ├─ hass          hostNetwork :8123   hostPath /var/lib/hass
    │    ├─ mosquitto     hostNetwork :1883   ConfigMap + passwd Secret
    │    ├─ zigbee2mqtt-wifi   ClusterIP :8080   hostPath .../zigbee2mqtt-wifi
    │    ├─ zigbee2mqtt-usb    ClusterIP :8080   hostPath .../zigbee2mqtt-usb
    │    │                      + /dev/ttyUSB0
    │    └─ hass-timemachine   ClusterIP :3000   hostPath config + media/timemachine
    └─ namespace cloudnative-pg
         Database homeassistant + DatabaseRole hass_user
              └─ Cluster/postgres  (postgres-rw.cloudnative-pg.svc)

Traefik-k8s IngressRoute (namespace hass) → Service → pod
LAN MQTT clients → 192.168.89.252:1883
Home Assistant   → 127.0.0.1:1883 (anonymous) and CNPG Service (recorder)
```

Every pod tolerates `node-role.kubernetes.io/control-plane` and sets `app.kubernetes.io` `name`, `instance`, `part-of`, and `managed-by`.

## GitOps layout

```
kubernetes/argocd/resources/application-hass.yaml   # listed from resources/kustomization.yaml
kubernetes/hass/
  kustomization.yaml
  resources/
    namespace.yaml
    hass.yaml                  # Deployment + Service
    mosquitto.yaml             # Deployment + ConfigMap
    zigbee2mqtt-wifi.yaml
    zigbee2mqtt-usb.yaml
    timemachine.yaml
    ingressroute.yaml          # four hosts
    externalsecret.yaml        # passwd, zigbee mqtt, timemachine token, db role
    database.yaml              # Database + DatabaseRole, namespace cloudnative-pg
```

The Application source path is `kubernetes/hass`, destination namespace `hass`, `CreateNamespace=true`, automated prune and self-heal, server-side apply. `database.yaml` sets `metadata.namespace: cloudnative-pg` so the CRs land next to the Cluster.

Image tags match the compose file at design time:

- `ghcr.io/home-assistant/home-assistant:2026.9.3`
- `ghcr.io/koenkk/zigbee2mqtt:2.14.1` (both)
- `eclipse-mosquitto:2.1.2-alpine`
- `ghcr.io/saihgupr/homeassistanttimemachine:2.3.2`

## Workloads

**Home Assistant.** `hostNetwork`, `dnsPolicy: ClusterFirstWithHostNet`. Mount `/var/lib/hass` at `/config` and `/var/lib/hass/media` at `/media`. `hostPath` type `Directory` (missing path fails the pod; Kubernetes must not create an empty config tree). Probes hit `127.0.0.1:8123`.

**Mosquitto.** `hostNetwork`. ConfigMap listeners:

- `1883` on `127.0.0.1`, anonymous (Home Assistant and the broker healthcheck).
- `1883` on `192.168.89.252`, password file, anonymous off.

No `0.0.0.0` listener and no Docker-bridge listener. Passwd Secret mounted with `fsGroup: 1883` and mode `0440`. Data directory hostPath `/var/lib/hass/mosquitto-data`.

**Zigbee2MQTT.** ClusterIP Service port 8080. Env from ExternalSecret: `ZIGBEE2MQTT_CONFIG_MQTT_SERVER=mqtt://192.168.89.252:1883`, user `mqtt`, password from 1Password. USB Deployment mounts hostPath `/dev/ttyUSB0` and sets `securityContext.privileged: true` so the process can open the serial device. Wi-Fi coordinator settings stay inside the copied data directory.

**Time Machine.** ClusterIP port 3000. `HOME_ASSISTANT_URL=http://192.168.89.252:8123`. Token from ExternalSecret `LONG_LIVED_ACCESS_TOKEN`. Mounts the HA config hostPath and `/var/lib/hass/media/timemachine`.

Zigbee Deployments start only after Mosquitto is ready. Home Assistant starts only after Mosquitto is ready.

## Data and secrets

1Password items, read by ExternalSecrets through the existing ClusterSecretStore:

| Secret | Consumed by |
|--------|-------------|
| Mosquitto passwd file contents | Mosquitto volume |
| MQTT user `mqtt` password | Zigbee2MQTT env |
| Time Machine long-lived token | Time Machine env |
| `hass_user` password (`kubernetes.io/basic-auth`) | `DatabaseRole` in `cloudnative-pg` |

`Database` name `homeassistant`, owner `hass_user`, cluster `postgres`. CNPG requires these CRs in the Cluster namespace.

Home Assistant's copied config keeps MQTT on `127.0.0.1`. The recorder URL in that config is edited during cutover to `postgres-rw.cloudnative-pg.svc` with `hass_user` and database `homeassistant`. `ClusterFirstWithHostNet` is what resolves that Service from the host-network pod.

`pg_dump` of `homeassistant` runs on the Portainer host (Postgres is localhost-only). Restore into the CNPG database after the role exists and before Home Assistant is started. The dump stays outside the git repo.

## Edge

IngressRoutes in namespace `hass`, TLS from the Traefik default store, middleware refs in namespace `traefik`:

| Host | Middlewares | Service |
|------|-------------|---------|
| `hass.dominiksiejak.pl` | crowdsec-bouncer, secure-headers | `hass:8123` |
| `zigbee2mqtt-wifi.dominiksiejak.pl` | those two + authentik | `zigbee2mqtt-wifi:8080` |
| `zigbee2mqtt-usb.dominiksiejak.pl` | those two + authentik | `zigbee2mqtt-usb:8080` |
| `hass-timemachine.dominiksiejak.pl` | those two + authentik | `hass-timemachine:3000` |

Remove those four `Host()` matchers from `kubernetes/traefik/resources/routes/portainer-native-oidc.yaml` and `portainer-forward-auth.yaml` in the same change. Authentik apps, homepage tiles, and `scripts/auth_classification.yaml` stay, because the hostnames and classes do not change.

`scripts/check-consistency.py` is referenced by the root Makefile and is absent in the tree right now. When it returns, its Traefik host set has to include IngressRoute `Host()` values. Until then, dropping the compose labels removes these hosts from the old source of truth.

## Cutover

Prepare the node while compose is still the one serving traffic. Push git only after the disk and the database are ready. Argo auto-syncs `main`.

1. Move the USB stick to the lake node. Confirm `/dev/ttyUSB0`.
2. Stop the Portainer `hass` stack so only one broker and one Zigbee coordinator run.
3. Rsync `/var/lib/hass` from Portainer to the lake node. Preserve Zigbee data, HA config, and media.
4. `pg_dump` `homeassistant` on Portainer. Apply `kubernetes/hass/resources/database.yaml` and the database ExternalSecret before the rest of the Application syncs, so `hass_user` exists. Restore into CloudNativePG. Set the recorder URL in the copied HA config.
5. Repoint LAN MQTT clients (Tasmota and similar) from `192.168.89.253:1883` to `192.168.89.252:1883`. Same user and password.
6. Push the gitops change: Application, manifests, IngressRoute move, delete `stacks/hass`, drop `hass` from `terraform/portainer/locals.tf`.
7. `make apply` in `terraform/portainer` so the compose stack is removed. Argo syncs the Application.

A pod that starts against an empty `/var/lib/hass` is avoided by `hostPath` type `Directory` plus step 3 happening first.

## Rollback

Keep the Portainer `/var/lib/hass` tree and the Postgres dump until the new stack has been healthy for a day. Rollback is: scale the Application down (or drop the Application), start the compose stack again, move the USB stick back, point LAN MQTT clients at `.253`. Recorder writes made on CloudNativePG after cutover are not in compose Postgres.

## Verification

- `mosquitto_sub` to `127.0.0.1:1883` on the node succeeds without a password. The same subscribe to `192.168.89.252:1883` requires the MQTT user.
- Home Assistant UI on `https://hass.dominiksiejak.pl` completes Authentik OIDC (app-level, no Traefik forward-auth).
- Zigbee frontends and Time Machine prompt at Traefik forward-auth.
- USB Zigbee devices stay paired. Wi-Fi coordinator stays connected.
- Recorder history from before the dump is visible in Home Assistant.
- A LAN MQTT client published to `.252` shows up in Home Assistant.
- Portainer no longer runs the `hass` stack.

## Docs

Update `AGENTS.md` (stack location, Mosquitto listeners, hostPath, no compose profile) and the README services row plus a changelog entry dated the day of the change.
