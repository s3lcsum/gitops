# Home Assistant on Kubernetes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** GitOps the Portainer `hass` stack onto the lake node as a Kustomize Argo CD Application, with the recorder on CloudNativePG.

**Architecture:** `kubernetes/hass` holds Deployments, Services, IngressRoutes, ExternalSecrets, and the CNPG `Database` / `DatabaseRole`. A dedicated Application (`kubernetes/argocd/resources/application-hass.yaml`) syncs that path. Home Assistant and Mosquitto use `hostNetwork` on `192.168.89.252`. Zigbee2MQTT and Time Machine use ClusterIP and reach MQTT at that address. Config is a hostPath of `/var/lib/hass`. Compose leaves `terraform/portainer` in the last task.

**Tech Stack:** Kubernetes Deployments, Traefik IngressRoute, External Secrets Operator (1Password ClusterSecretStore `onepassword`), CloudNativePG 1.30 `Database` / `DatabaseRole`, Argo CD Application.

**Spec:** `docs/superpowers/specs/2026-09-26-hass-kubernetes-design.md`

## Global Constraints

- Images: `ghcr.io/home-assistant/home-assistant:2026.9.3`, `ghcr.io/koenkk/zigbee2mqtt:2.14.1`, `eclipse-mosquitto:2.1.2-alpine`, `ghcr.io/saihgupr/homeassistanttimemachine:2.3.2`.
- Home Assistant and Mosquitto: `hostNetwork: true` on `192.168.89.252`. Home Assistant `dnsPolicy: ClusterFirstWithHostNet`.
- Mosquitto listeners: anonymous `127.0.0.1:1883`, password `192.168.89.252:1883`. No `0.0.0.0` listener. No `172.17.0.1` listener.
- Zigbee and Time Machine stay on the pod network. MQTT URL `mqtt://192.168.89.252:1883`, user `mqtt`.
- hostPath `/var/lib/hass` type `Directory`. Do not mount a Docker socket.
- USB pod: hostPath `/dev/ttyUSB0` type `CharDevice`, `securityContext.privileged: true`.
- Every pod tolerates `node-role.kubernetes.io/control-plane` Exists / NoSchedule.
- Every pod has non-empty `app.kubernetes.io/name`, `instance`, `part-of`, `managed-by`.
- `part-of` is `hass`. `managed-by` is `argocd`.
- Database CRs use `metadata.namespace: cloudnative-pg`, cluster name `postgres`, database `homeassistant`, role `hass_user`.
- Recorder host is `postgres-rw.cloudnative-pg.svc`. The URL edit happens on the copied config during cutover, not in git.
- IngressRoutes live in namespace `hass`. Middleware refs use `namespace: traefik`. `hass` is crowdsec + secure-headers only. The other three add `authentik`.
- 1Password vault is `Servers`. Item tag is `ArgoCD External Secrets Operator`. No secret values in git.
- Do not add `kubernetes/hass/values.yaml`. That would enroll the app in the Helm ApplicationSet.
- Timezone `Europe/Warsaw`.
- Public repo. Do not commit dumps, passwd files, or tokens.

## File map

| Path | Responsibility |
|------|----------------|
| `kubernetes/hass/kustomization.yaml` | Lists every manifest |
| `kubernetes/hass/resources/namespace.yaml` | Namespace `hass` |
| `kubernetes/hass/resources/externalsecret.yaml` | 1Password → passwd, MQTT, Time Machine token, DB role |
| `kubernetes/hass/resources/database.yaml` | `DatabaseRole` `hass_user` + `Database` `homeassistant` |
| `kubernetes/hass/resources/mosquitto.yaml` | ConfigMap, Deployment |
| `kubernetes/hass/resources/hass.yaml` | Deployment + Service `:8123` |
| `kubernetes/hass/resources/zigbee2mqtt-wifi.yaml` | Deployment + Service |
| `kubernetes/hass/resources/zigbee2mqtt-usb.yaml` | Deployment + Service + `/dev/ttyUSB0` |
| `kubernetes/hass/resources/timemachine.yaml` | Deployment + Service |
| `kubernetes/hass/resources/ingressroute.yaml` | Four hosts |
| `kubernetes/argocd/resources/application-hass.yaml` | Argo Application |
| `kubernetes/argocd/resources/kustomization.yaml` | Lists the Application |
| `kubernetes/traefik/resources/routes/portainer-native-oidc.yaml` | Drop `hass` hop |
| `kubernetes/traefik/resources/routes/portainer-forward-auth.yaml` | Drop the other three hops |
| `terraform/portainer/locals.tf` | Drop stack `hass` |
| `stacks/hass/` | Deleted |
| `AGENTS.md`, `README.md` | Location, listeners, changelog |

## Prerequisites (human, before the git push)

The implementer writes git. Do not push `main` until these are done. Argo auto-syncs `main` and will start pods.

1. USB Zigbee stick is on the lake node and shows up as `/dev/ttyUSB0`.
2. Stop the Portainer `hass` stack (one broker, one coordinator).
3. Rsync `/var/lib/hass` from Portainer onto the lake node at `/var/lib/hass`.
4. Copy Docker volume `hass_mosquitto_data` to `/var/lib/hass/mosquitto-data` on the lake node. Copy Docker volume `hass_ha_time_machine_data` to `/var/lib/hass/media/timemachine`.
5. 1Password vault `Servers`, tag `ArgoCD External Secrets Operator`:
   - Item `hass-mosquitto`, field `passwd`: Mosquitto password-file body (hashed line for user `mqtt`).
   - Item `hass-mqtt`, fields `username` (`mqtt`) and `password` (plaintext, same credential).
   - Item `hass-timemachine`, field `LONG_LIVED_ACCESS_TOKEN`.
   - Item `hass-database`, field `password`: password for role `hass_user`.
6. `pg_dump` database `homeassistant` on Portainer (Postgres is `127.0.0.1:5432`). Keep the dump outside the git repo.
7. After Task 1 is synced (or applied once), restore that dump into CloudNativePG as `hass_user` / `homeassistant`. Then set the recorder URL in the copied HA config to `postgres-rw.cloudnative-pg.svc` with that user and database. Do not start the Home Assistant pod before the restore.
8. Repoint LAN MQTT clients from `192.168.89.253:1883` to `192.168.89.252:1883`.

---

### Task 1: Namespace, secrets, CloudNativePG database

**Files:**
- Create: `kubernetes/hass/kustomization.yaml`
- Create: `kubernetes/hass/resources/namespace.yaml`
- Create: `kubernetes/hass/resources/externalsecret.yaml`
- Create: `kubernetes/hass/resources/database.yaml`

**Interfaces:**
- Consumes: ClusterSecretStore `onepassword`, Cluster `postgres` in `cloudnative-pg`
- Produces: Secret `hass-mosquitto` key `passwd`; Secret `hass-mqtt` keys `username` and `password`; Secret `hass-timemachine` key `LONG_LIVED_ACCESS_TOKEN` (all namespace `hass`); Secret `hass-user` type `kubernetes.io/basic-auth` keys `username` and `password` (namespace `cloudnative-pg`); `DatabaseRole` name `hass-user` (`spec.name` `hass_user`); `Database` name `homeassistant`

- [ ] **Step 1: Confirm the directory is absent**

Run: `kubectl kustomize kubernetes/hass`

Expected: non-zero exit, error containing `kubernetes/hass`

- [ ] **Step 2: Write the manifests**

`kubernetes/hass/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - resources/namespace.yaml
  - resources/externalsecret.yaml
  - resources/database.yaml
```

`kubernetes/hass/resources/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hass
  labels:
    app.kubernetes.io/name: hass
    app.kubernetes.io/part-of: hass
```

`kubernetes/hass/resources/externalsecret.yaml`

```yaml
# 1Password vault Servers. Tag: ArgoCD External Secrets Operator
# Items: hass-mosquitto/passwd, hass-mqtt/username, hass-mqtt/password,
# hass-timemachine/LONG_LIVED_ACCESS_TOKEN, hass-database/password
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hass-mosquitto
  namespace: hass
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: hass-mosquitto
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
  data:
    - secretKey: passwd
      remoteRef:
        key: hass-mosquitto/passwd
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hass-mqtt
  namespace: hass
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: hass-mqtt
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
  data:
    - secretKey: username
      remoteRef:
        key: hass-mqtt/username
    - secretKey: password
      remoteRef:
        key: hass-mqtt/password
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hass-timemachine
  namespace: hass
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: hass-timemachine
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
  data:
    - secretKey: LONG_LIVED_ACCESS_TOKEN
      remoteRef:
        key: hass-timemachine/LONG_LIVED_ACCESS_TOKEN
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hass-user
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: hass-user
    creationPolicy: Owner
    deletionPolicy: Retain
    template:
      engineVersion: v2
      type: kubernetes.io/basic-auth
      metadata:
        labels: {}
        annotations:
          argocd.argoproj.io/sync-options: Prune=false
      data:
        username: hass_user
        password: "{{ .password }}"
  data:
    - secretKey: password
      remoteRef:
        key: hass-database/password
```

`kubernetes/hass/resources/database.yaml`

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata:
  name: hass-user
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  cluster:
    name: postgres
  name: hass_user
  login: true
  databaseRoleReclaimPolicy: delete
  passwordSecret:
    name: hass-user
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata:
  name: homeassistant
  namespace: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
spec:
  name: homeassistant
  owner: hass_user
  cluster:
    name: postgres
```

- [ ] **Step 3: Render**

Run: `kubectl kustomize kubernetes/hass`

Expected: exit 0. Output contains `kind: Namespace`, `name: hass-user`, `name: homeassistant`, `key: hass-mosquitto/passwd`.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/hass/kustomization.yaml kubernetes/hass/resources/namespace.yaml kubernetes/hass/resources/externalsecret.yaml kubernetes/hass/resources/database.yaml
git commit -m "$(cat <<'EOF'
feat(k8s): add hass namespace, secrets, and CloudNativePG database

EOF
)"
```

---

### Task 2: Mosquitto

**Files:**
- Create: `kubernetes/hass/resources/mosquitto.yaml`
- Modify: `kubernetes/hass/kustomization.yaml`

**Interfaces:**
- Consumes: Secret `hass-mosquitto` key `passwd`
- Produces: Deployment `mosquitto` in namespace `hass`, hostNetwork, listeners `127.0.0.1:1883` and `192.168.89.252:1883`

- [ ] **Step 1: Confirm the Deployment is absent**

Run: `kubectl kustomize kubernetes/hass | grep 'name: mosquitto'`

Expected: no output, exit 1

- [ ] **Step 2: Write the workload and list it**

Replace `kubernetes/hass/kustomization.yaml` with:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - resources/namespace.yaml
  - resources/externalsecret.yaml
  - resources/database.yaml
  - resources/mosquitto.yaml
```

`kubernetes/hass/resources/mosquitto.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mosquitto
  namespace: hass
  labels:
    app.kubernetes.io/name: mosquitto
    app.kubernetes.io/instance: mosquitto
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
data:
  mosquitto.conf: |
    persistence true
    persistence_location /mosquitto/data/
    listener 1883 127.0.0.1
    listener_allow_anonymous true
    listener 1883 192.168.89.252
    listener_allow_anonymous false
    password_file /mosquitto/config/passwd
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mosquitto
  namespace: hass
  labels:
    app.kubernetes.io/name: mosquitto
    app.kubernetes.io/instance: mosquitto
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: mosquitto
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mosquitto
        app.kubernetes.io/instance: mosquitto
        app.kubernetes.io/part-of: hass
        app.kubernetes.io/managed-by: argocd
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      securityContext:
        runAsUser: 1883
        runAsGroup: 1883
        fsGroup: 1883
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: mosquitto
          image: eclipse-mosquitto:2.1.2-alpine
          ports:
            - name: mqtt
              containerPort: 1883
          volumeMounts:
            - name: config
              mountPath: /mosquitto/config
              readOnly: true
            - name: data
              mountPath: /mosquitto/data
          readinessProbe:
            exec:
              command:
                - mosquitto_sub
                - -h
                - 127.0.0.1
                - -p
                - "1883"
                - -t
                - $SYS/broker/uptime
                - -C
                - "1"
                - -W
                - "3"
            periodSeconds: 10
            timeoutSeconds: 5
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
      volumes:
        # One projected dir. subPath mounts ignore fsGroup, so uid 1883 could not read the passwd file.
        - name: config
          projected:
            sources:
              - configMap:
                  name: mosquitto
                  items:
                    - key: mosquitto.conf
                      path: mosquitto.conf
                      mode: 292 # 0444
              - secret:
                  name: hass-mosquitto
                  items:
                    - key: passwd
                      path: passwd
                      mode: 292 # 0444
        - name: data
          hostPath:
            path: /var/lib/hass/mosquitto-data
            type: DirectoryOrCreate
```

- [ ] **Step 3: Render**

Run: `kubectl kustomize kubernetes/hass | grep -E '192.168.89.252|127.0.0.1|eclipse-mosquitto:2.1.2-alpine'`

Expected: all three strings present. Output must not contain `0.0.0.0` or `172.17.0.1`.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/hass/kustomization.yaml kubernetes/hass/resources/mosquitto.yaml
git commit -m "$(cat <<'EOF'
feat(k8s): run mosquitto on the lake node network

EOF
)"
```

---

### Task 3: Home Assistant

**Files:**
- Create: `kubernetes/hass/resources/hass.yaml`
- Modify: `kubernetes/hass/kustomization.yaml`

**Interfaces:**
- Consumes: Mosquitto on `127.0.0.1:1883` in the host network namespace; hostPath `/var/lib/hass`
- Produces: Deployment `hass`, Service `hass` port `8123`

- [ ] **Step 1: Confirm the Deployment is absent**

Run: `kubectl kustomize kubernetes/hass | grep 'home-assistant:2026.9.3'`

Expected: no output, exit 1

- [ ] **Step 2: Write the workload and list it**

Add `- resources/hass.yaml` at the end of `resources:` in `kubernetes/hass/kustomization.yaml`.

`kubernetes/hass/resources/hass.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hass
  namespace: hass
  labels:
    app.kubernetes.io/name: hass
    app.kubernetes.io/instance: hass
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: hass
  template:
    metadata:
      labels:
        app.kubernetes.io/name: hass
        app.kubernetes.io/instance: hass
        app.kubernetes.io/part-of: hass
        app.kubernetes.io/managed-by: argocd
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      initContainers:
        - name: wait-mqtt
          image: eclipse-mosquitto:2.1.2-alpine
          command:
            - sh
            - -c
            - until mosquitto_sub -h 127.0.0.1 -p 1883 -t '$SYS/broker/uptime' -C 1 -W 3; do sleep 2; done
      containers:
        - name: hass
          image: ghcr.io/home-assistant/home-assistant:2026.9.3
          env:
            - name: TZ
              value: Europe/Warsaw
          ports:
            - name: http
              containerPort: 8123
          volumeMounts:
            - name: config
              mountPath: /config
            - name: media
              mountPath: /media
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 30
            timeoutSeconds: 10
          resources:
            requests:
              cpu: 100m
              memory: 512Mi
      volumes:
        - name: config
          hostPath:
            path: /var/lib/hass
            type: Directory
        - name: media
          hostPath:
            path: /var/lib/hass/media
            type: Directory
---
apiVersion: v1
kind: Service
metadata:
  name: hass
  namespace: hass
  labels:
    app.kubernetes.io/name: hass
    app.kubernetes.io/instance: hass
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
spec:
  selector:
    app.kubernetes.io/name: hass
  ports:
    - name: http
      port: 8123
      targetPort: http
```

- [ ] **Step 3: Render**

Run: `kubectl kustomize kubernetes/hass | grep -E 'home-assistant:2026.9.3|ClusterFirstWithHostNet|docker.sock'`

Expected: image and `ClusterFirstWithHostNet` present. `docker.sock` absent (grep exit 1 is correct if the first two matched — run them as two commands).

```bash
kubectl kustomize kubernetes/hass | grep 'home-assistant:2026.9.3'
kubectl kustomize kubernetes/hass | grep 'ClusterFirstWithHostNet'
if kubectl kustomize kubernetes/hass | grep -q 'docker.sock'; then exit 1; fi
```

Expected: first two commands print a match. Third command exits 0.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/hass/kustomization.yaml kubernetes/hass/resources/hass.yaml
git commit -m "$(cat <<'EOF'
feat(k8s): run Home Assistant on the lake node network

EOF
)"
```

---

### Task 4: Zigbee2MQTT

**Files:**
- Create: `kubernetes/hass/resources/zigbee2mqtt-wifi.yaml`
- Create: `kubernetes/hass/resources/zigbee2mqtt-usb.yaml`
- Modify: `kubernetes/hass/kustomization.yaml`

**Interfaces:**
- Consumes: Secret `hass-mqtt` keys `username` and `password`; broker `192.168.89.252:1883`
- Produces: Deployments and Services `zigbee2mqtt-wifi` and `zigbee2mqtt-usb`, both port `8080`

- [ ] **Step 1: Confirm both are absent**

Run: `kubectl kustomize kubernetes/hass | grep 'zigbee2mqtt:2.14.1'`

Expected: no output, exit 1

- [ ] **Step 2: Write both workloads and list them**

Add these lines at the end of `resources:` in `kubernetes/hass/kustomization.yaml`:

```yaml
  - resources/zigbee2mqtt-wifi.yaml
  - resources/zigbee2mqtt-usb.yaml
```

`kubernetes/hass/resources/zigbee2mqtt-wifi.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zigbee2mqtt-wifi
  namespace: hass
  labels:
    app.kubernetes.io/name: zigbee2mqtt-wifi
    app.kubernetes.io/instance: zigbee2mqtt-wifi
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: zigbee2mqtt-wifi
  template:
    metadata:
      labels:
        app.kubernetes.io/name: zigbee2mqtt-wifi
        app.kubernetes.io/instance: zigbee2mqtt-wifi
        app.kubernetes.io/part-of: hass
        app.kubernetes.io/managed-by: argocd
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      initContainers:
        - name: wait-mqtt
          image: eclipse-mosquitto:2.1.2-alpine
          env:
            - name: MQTT_USER
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: username
            - name: MQTT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: password
          command:
            - sh
            - -c
            - until mosquitto_sub -h 192.168.89.252 -p 1883 -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t '$SYS/broker/uptime' -C 1 -W 3; do sleep 2; done
      containers:
        - name: zigbee2mqtt
          image: ghcr.io/koenkk/zigbee2mqtt:2.14.1
          env:
            - name: TZ
              value: Europe/Warsaw
            - name: ZIGBEE2MQTT_CONFIG_MQTT_SERVER
              value: mqtt://192.168.89.252:1883
            - name: ZIGBEE2MQTT_CONFIG_MQTT_USER
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: username
            - name: ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: password
          ports:
            - name: http
              containerPort: 8080
          volumeMounts:
            - name: data
              mountPath: /app/data
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 30
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
      volumes:
        - name: data
          hostPath:
            path: /var/lib/hass/zigbee2mqtt-wifi
            type: Directory
---
apiVersion: v1
kind: Service
metadata:
  name: zigbee2mqtt-wifi
  namespace: hass
  labels:
    app.kubernetes.io/name: zigbee2mqtt-wifi
    app.kubernetes.io/instance: zigbee2mqtt-wifi
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
spec:
  selector:
    app.kubernetes.io/name: zigbee2mqtt-wifi
  ports:
    - name: http
      port: 8080
      targetPort: http
```

`kubernetes/hass/resources/zigbee2mqtt-usb.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zigbee2mqtt-usb
  namespace: hass
  labels:
    app.kubernetes.io/name: zigbee2mqtt-usb
    app.kubernetes.io/instance: zigbee2mqtt-usb
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: zigbee2mqtt-usb
  template:
    metadata:
      labels:
        app.kubernetes.io/name: zigbee2mqtt-usb
        app.kubernetes.io/instance: zigbee2mqtt-usb
        app.kubernetes.io/part-of: hass
        app.kubernetes.io/managed-by: argocd
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      initContainers:
        - name: wait-mqtt
          image: eclipse-mosquitto:2.1.2-alpine
          env:
            - name: MQTT_USER
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: username
            - name: MQTT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: password
          command:
            - sh
            - -c
            - until mosquitto_sub -h 192.168.89.252 -p 1883 -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t '$SYS/broker/uptime' -C 1 -W 3; do sleep 2; done
      containers:
        - name: zigbee2mqtt
          image: ghcr.io/koenkk/zigbee2mqtt:2.14.1
          securityContext:
            privileged: true
          env:
            - name: TZ
              value: Europe/Warsaw
            - name: ZIGBEE2MQTT_CONFIG_MQTT_SERVER
              value: mqtt://192.168.89.252:1883
            - name: ZIGBEE2MQTT_CONFIG_MQTT_USER
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: username
            - name: ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: hass-mqtt
                  key: password
          ports:
            - name: http
              containerPort: 8080
          volumeMounts:
            - name: data
              mountPath: /app/data
            - name: usb
              mountPath: /dev/ttyUSB0
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 30
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
      volumes:
        - name: data
          hostPath:
            path: /var/lib/hass/zigbee2mqtt-usb
            type: Directory
        - name: usb
          hostPath:
            path: /dev/ttyUSB0
            type: CharDevice
---
apiVersion: v1
kind: Service
metadata:
  name: zigbee2mqtt-usb
  namespace: hass
  labels:
    app.kubernetes.io/name: zigbee2mqtt-usb
    app.kubernetes.io/instance: zigbee2mqtt-usb
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
spec:
  selector:
    app.kubernetes.io/name: zigbee2mqtt-usb
  ports:
    - name: http
      port: 8080
      targetPort: http
```

- [ ] **Step 3: Render**

```bash
kubectl kustomize kubernetes/hass | grep -c 'image: ghcr.io/koenkk/zigbee2mqtt:2.14.1'
kubectl kustomize kubernetes/hass | grep 'ttyUSB0'
```

Expected: count `2`, and a line containing `ttyUSB0`.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/hass/kustomization.yaml kubernetes/hass/resources/zigbee2mqtt-wifi.yaml kubernetes/hass/resources/zigbee2mqtt-usb.yaml
git commit -m "$(cat <<'EOF'
feat(k8s): run both Zigbee2MQTT coordinators in-cluster

EOF
)"
```

---

### Task 5: HA Time Machine

**Files:**
- Create: `kubernetes/hass/resources/timemachine.yaml`
- Modify: `kubernetes/hass/kustomization.yaml`

**Interfaces:**
- Consumes: Secret `hass-timemachine` key `LONG_LIVED_ACCESS_TOKEN`; Home Assistant at `http://192.168.89.252:8123`
- Produces: Deployment and Service `hass-timemachine` port `3000`

- [ ] **Step 1: Confirm it is absent**

Run: `kubectl kustomize kubernetes/hass | grep 'homeassistanttimemachine:2.3.2'`

Expected: no output, exit 1

- [ ] **Step 2: Write the workload and list it**

Add `- resources/timemachine.yaml` at the end of `resources:` in `kubernetes/hass/kustomization.yaml`.

`kubernetes/hass/resources/timemachine.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hass-timemachine
  namespace: hass
  labels:
    app.kubernetes.io/name: hass-timemachine
    app.kubernetes.io/instance: hass-timemachine
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: hass-timemachine
  template:
    metadata:
      labels:
        app.kubernetes.io/name: hass-timemachine
        app.kubernetes.io/instance: hass-timemachine
        app.kubernetes.io/part-of: hass
        app.kubernetes.io/managed-by: argocd
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: timemachine
          image: ghcr.io/saihgupr/homeassistanttimemachine:2.3.2
          env:
            - name: TZ
              value: Europe/Warsaw
            - name: HOME_ASSISTANT_URL
              value: http://192.168.89.252:8123
            - name: ESPHOME_CONFIG_PATH
              value: /esphome
            - name: DEBUG_LOGS
              value: "false"
            - name: THEME
              value: dark
            - name: LONG_LIVED_ACCESS_TOKEN
              valueFrom:
                secretKeyRef:
                  name: hass-timemachine
                  key: LONG_LIVED_ACCESS_TOKEN
          ports:
            - name: http
              containerPort: 3000
          volumeMounts:
            - name: config
              mountPath: /config
            - name: exports
              mountPath: /media/timemachine
          readinessProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 30
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
      volumes:
        - name: config
          hostPath:
            path: /var/lib/hass
            type: Directory
        - name: exports
          hostPath:
            path: /var/lib/hass/media/timemachine
            type: DirectoryOrCreate
---
apiVersion: v1
kind: Service
metadata:
  name: hass-timemachine
  namespace: hass
  labels:
    app.kubernetes.io/name: hass-timemachine
    app.kubernetes.io/instance: hass-timemachine
    app.kubernetes.io/part-of: hass
    app.kubernetes.io/managed-by: argocd
spec:
  selector:
    app.kubernetes.io/name: hass-timemachine
  ports:
    - name: http
      port: 3000
      targetPort: http
```

- [ ] **Step 3: Render**

Run: `kubectl kustomize kubernetes/hass | grep -E 'homeassistanttimemachine:2.3.2|HOME_ASSISTANT_URL'`

Expected: both strings present.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/hass/kustomization.yaml kubernetes/hass/resources/timemachine.yaml
git commit -m "$(cat <<'EOF'
feat(k8s): run HA Time Machine next to Home Assistant

EOF
)"
```

---

### Task 6: IngressRoutes

**Files:**
- Create: `kubernetes/hass/resources/ingressroute.yaml`
- Modify: `kubernetes/hass/kustomization.yaml`

**Interfaces:**
- Consumes: Services `hass:8123`, `zigbee2mqtt-wifi:8080`, `zigbee2mqtt-usb:8080`, `hass-timemachine:3000`; middlewares `crowdsec-bouncer`, `secure-headers`, `authentik` in namespace `traefik`
- Produces: IngressRoute `hass` in namespace `hass`

- [ ] **Step 1: Confirm the route is absent**

Run: `kubectl kustomize kubernetes/hass | grep 'kind: IngressRoute'`

Expected: no output, exit 1

- [ ] **Step 2: Write the route and list it**

Add `- resources/ingressroute.yaml` at the end of `resources:` in `kubernetes/hass/kustomization.yaml`.

`kubernetes/hass/resources/ingressroute.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: hass
  namespace: hass
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`hass.dominiksiejak.pl`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
          namespace: traefik
        - name: secure-headers
          namespace: traefik
      services:
        - name: hass
          port: 8123
    - match: Host(`zigbee2mqtt-wifi.dominiksiejak.pl`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
          namespace: traefik
        - name: secure-headers
          namespace: traefik
        - name: authentik
          namespace: traefik
      services:
        - name: zigbee2mqtt-wifi
          port: 8080
    - match: Host(`zigbee2mqtt-usb.dominiksiejak.pl`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
          namespace: traefik
        - name: secure-headers
          namespace: traefik
        - name: authentik
          namespace: traefik
      services:
        - name: zigbee2mqtt-usb
          port: 8080
    - match: Host(`hass-timemachine.dominiksiejak.pl`)
      kind: Rule
      middlewares:
        - name: crowdsec-bouncer
          namespace: traefik
        - name: secure-headers
          namespace: traefik
        - name: authentik
          namespace: traefik
      services:
        - name: hass-timemachine
          port: 3000
  tls: {}
```

- [ ] **Step 3: Render**

```bash
kubectl kustomize kubernetes/hass | grep -c 'dominiksiejak.pl'
```

Expected: `4`

- [ ] **Step 4: Commit**

```bash
git add kubernetes/hass/kustomization.yaml kubernetes/hass/resources/ingressroute.yaml
git commit -m "$(cat <<'EOF'
feat(k8s): route hass hosts through Traefik-k8s

EOF
)"
```

---

### Task 7: Argo CD Application

**Files:**
- Create: `kubernetes/argocd/resources/application-hass.yaml`
- Modify: `kubernetes/argocd/resources/kustomization.yaml`

**Interfaces:**
- Consumes: path `kubernetes/hass`
- Produces: Application `hass` in namespace `argocd`, destination namespace `hass`, prune and self-heal on

- [ ] **Step 1: Confirm the Application is absent**

Run: `grep -n application-hass kubernetes/argocd/resources/kustomization.yaml`

Expected: no output, exit 1

- [ ] **Step 2: Write the Application and list it**

`kubernetes/argocd/resources/application-hass.yaml`

```yaml
# Kustomize only. No values.yaml → not in the Helm ApplicationSet.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hass
  namespace: argocd
  labels:
    app.kubernetes.io/name: hass
    app.kubernetes.io/part-of: kubernetes
spec:
  project: default
  source:
    repoURL: https://github.com/s3lcsum/gitops.git
    targetRevision: main
    path: kubernetes/hass
  destination:
    server: https://kubernetes.default.svc
    namespace: hass
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - ServerSideDiff=true
```

Add a line to `kubernetes/argocd/resources/kustomization.yaml` `resources:` immediately after `application-coredns.yaml`:

```yaml
  - application-hass.yaml
```

- [ ] **Step 3: Render the Argo app**

Run: `kubectl kustomize kubernetes/argocd/resources | grep 'path: kubernetes/hass'`

Expected: one match. Also confirm there is still no `kubernetes/hass/values.yaml`:

```bash
test ! -f kubernetes/hass/values.yaml
```

Expected: exit 0

- [ ] **Step 4: Commit**

```bash
git add kubernetes/argocd/resources/application-hass.yaml kubernetes/argocd/resources/kustomization.yaml
git commit -m "$(cat <<'EOF'
feat(k8s): sync hass with its own Argo CD Application

EOF
)"
```

---

### Task 8: Drop the Portainer hop for these hosts

**Files:**
- Modify: `kubernetes/traefik/resources/routes/portainer-native-oidc.yaml`
- Modify: `kubernetes/traefik/resources/routes/portainer-forward-auth.yaml`

**Interfaces:**
- Consumes: IngressRoute `hass` from Task 6
- Produces: hop matchers that no longer contain `hass.dominiksiejak.pl`, `hass-timemachine.dominiksiejak.pl`, `zigbee2mqtt-usb.dominiksiejak.pl`, `zigbee2mqtt-wifi.dominiksiejak.pl`

Do not edit `scripts/auth_classification.yaml` or `terraform/authentik/locals.tf`. Hostnames and auth classes stay.

- [ ] **Step 1: Confirm the hops still list the hosts**

```bash
grep -n 'Host(`hass.dominiksiejak.pl`)' kubernetes/traefik/resources/routes/portainer-native-oidc.yaml
grep -n 'zigbee2mqtt-wifi' kubernetes/traefik/resources/routes/portainer-forward-auth.yaml
```

Expected: both commands print a line.

- [ ] **Step 2: Remove the four matchers**

In `portainer-native-oidc.yaml`, delete the line:

```yaml
        Host(`hass.dominiksiejak.pl`) ||
```

In `portainer-forward-auth.yaml`, delete these three lines:

```yaml
        Host(`hass-timemachine.dominiksiejak.pl`) ||
        Host(`zigbee2mqtt-usb.dominiksiejak.pl`) ||
        Host(`zigbee2mqtt-wifi.dominiksiejak.pl`)
```

After the deletion, the forward-auth matcher must end with `Host(\`traefik.dominiksiejak.pl\`)` and no trailing `||`.

- [ ] **Step 3: Confirm they are gone**

```bash
if grep -R -E 'hass\.dominiksiejak|hass-timemachine|zigbee2mqtt-' kubernetes/traefik/resources/routes/portainer-native-oidc.yaml kubernetes/traefik/resources/routes/portainer-forward-auth.yaml; then exit 1; fi
```

Expected: exit 0

- [ ] **Step 4: Commit**

```bash
git add kubernetes/traefik/resources/routes/portainer-native-oidc.yaml kubernetes/traefik/resources/routes/portainer-forward-auth.yaml
git commit -m "$(cat <<'EOF'
fix(k8s): stop hopping hass hosts to Portainer Traefik

EOF
)"
```

---

### Task 9: Docs

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: layout from Tasks 1–8
- Produces: docs that describe hass on the lake node, listeners on `.252`, and a changelog entry under `### 26.09.2026`

- [ ] **Step 1: Update AGENTS.md**

In the `kubernetes/argocd/` bullet, the sentence that says sibling apps under `kubernetes/*` (except `argocd`) are parented by the ApplicationSet stays true for Helm apps. Add a sentence after the CoreDNS bullet:

```markdown
- `kubernetes/hass/` — Home Assistant, Mosquitto, Zigbee2MQTT Wi-Fi, Zigbee2MQTT USB, HA Time Machine. Kustomize Application `hass` (no `values.yaml`, so not in the Helm ApplicationSet). HA and Mosquitto are `hostNetwork` on `192.168.89.252` (`dnsPolicy: ClusterFirstWithHostNet` on HA). Mosquitto: anonymous `127.0.0.1:1883`, password `192.168.89.252:1883`. Config hostPath `/var/lib/hass` (`Directory`). USB stick `/dev/ttyUSB0` on the lake node. Recorder database `homeassistant` on CloudNativePG (`postgres-rw.cloudnative-pg.svc`). Secrets from 1Password via ExternalSecrets.
```

Replace the Home Assistant gotcha with:

```markdown
- Home Assistant runs on the lake node (`kubernetes/hass/`), not in `stacks/`. Mosquitto listens anonymous on `127.0.0.1:1883` and with a password on `192.168.89.252:1883`. Do not bind `0.0.0.0:1883` together with localhost. Passwd, MQTT password, Time Machine token, and `hass_user` come from 1Password. `/var/lib/hass` must already exist on the node (`hostPath` type `Directory`).
```

In the CloudNativePG bullet, replace `example resources/examples/smoke-database.yaml` with `kubernetes/hass/resources/database.yaml`.

- [ ] **Step 2: Update README.md**

Delete the services-table row that starts with `[Home Assistant stack]`.

Delete the tree line `│   ├── hass/`.

In the Kubernetes bullet under "Not in `stacks/`", add Home Assistant to the parenthetical list (`Home Assistant stack` after CloudNativePG).

Under `### 26.09.2026`, add this paragraph at the top of that date:

```markdown
**Home Assistant left Portainer.** The stack now lives in `kubernetes/hass/` (Argo Application `hass`, not the Helm ApplicationSet). Home Assistant and Mosquitto are `hostNetwork` on the lake node `192.168.89.252`. Zigbee2MQTT (Wi-Fi and USB) and HA Time Machine are normal pods. Recorder database `homeassistant` is on CloudNativePG. Traefik-k8s IngressRoutes own `hass`, `zigbee2mqtt-wifi`, `zigbee2mqtt-usb`, and `hass-timemachine` — those hosts no longer hop to Portainer. USB stick and `/var/lib/hass` have to be on the lake node before sync. Cutover steps are in `docs/superpowers/specs/2026-09-26-hass-kubernetes-design.md`.
```

Add a checked retro item in the TODO list (the block above the changelog):

```markdown
- [x] (retroactively added) Home Assistant stack on the lake node (`kubernetes/hass/`) instead of Portainer
```

- [ ] **Step 3: Confirm the old listener IP is gone from AGENTS.md**

```bash
if grep -n '192.168.89.253:1883\|172.17.0.1' AGENTS.md; then exit 1; fi
grep -n 'kubernetes/hass/' AGENTS.md README.md
```

Expected: first command exits 0. Second prints matches in both files.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md README.md
git commit -m "$(cat <<'EOF'
docs: point Home Assistant at the lake node

EOF
)"
```

---

### Task 10: Remove the compose stack

Do this commit only after the prerequisites are done and you are ready to push. Pushing `main` starts the pods and, once `terraform/portainer` is applied, deletes the compose stack.

**Files:**
- Modify: `terraform/portainer/locals.tf`
- Delete: `stacks/hass/` (tracked files only; host `/opt/hass` and `/var/lib/hass` stay until the operator removes them)

**Interfaces:**
- Consumes: working `kubernetes/hass` from Tasks 1–8
- Produces: `locals.stacks` without `hass`, no `stacks/hass` in git

- [ ] **Step 1: Confirm the stack is still listed**

Run: `grep -n '"hass"' terraform/portainer/locals.tf`

Expected: one match

- [ ] **Step 2: Drop it**

Delete the `"hass",` line from `locals.stacks` in `terraform/portainer/locals.tf`.

```bash
git rm -r stacks/hass
```

`git rm` removes tracked files (`compose.yaml`, `mosquitto.conf`, `*.env.example`). Gitignored `*.env` files are left on disk in the working tree if present. Do not commit those.

- [ ] **Step 3: Check**

```bash
test ! -d stacks/hass || test -z "$(git ls-files stacks/hass)"
grep -n '"hass"' terraform/portainer/locals.tf && exit 1 || true
make -C terraform/portainer check
```

Expected: `hass` is not a stack entry. `make check` exits 0.

- [ ] **Step 4: Commit**

```bash
git add terraform/portainer/locals.tf
git commit -m "$(cat <<'EOF'
feat: retire the Portainer hass stack

EOF
)"
```

`git rm` already stages the deletions. The `git add` picks up `locals.tf`.

## After push (operator)

Run from a host that can reach the cluster and the LAN. Context `k8s@lake`.

```bash
kubectl --context 'k8s@lake' -n hass rollout status deploy/mosquitto
kubectl --context 'k8s@lake' -n hass rollout status deploy/hass
kubectl --context 'k8s@lake' -n hass rollout status deploy/zigbee2mqtt-wifi
kubectl --context 'k8s@lake' -n hass rollout status deploy/zigbee2mqtt-usb
kubectl --context 'k8s@lake' -n hass rollout status deploy/hass-timemachine
```

Expected: each reports `successfully rolled out`.

On the lake node:

```bash
mosquitto_sub -h 127.0.0.1 -p 1883 -t '$SYS/broker/uptime' -C 1 -W 3
mosquitto_sub -h 192.168.89.252 -p 1883 -t '$SYS/broker/uptime' -C 1 -W 3
```

Expected: the first prints an uptime value. The second fails closed (connection refused or not authorized) because that listener requires the MQTT user.

```bash
mosquitto_sub -h 192.168.89.252 -p 1883 -u mqtt -P "$MQTT_PASSWORD" -t '$SYS/broker/uptime' -C 1 -W 3
```

Expected: prints an uptime value.

```bash
curl -sk -o /dev/null -w '%{http_code}\n' --resolve hass.dominiksiejak.pl:443:192.168.89.252 https://hass.dominiksiejak.pl/
```

Expected: `200` or `302` from Home Assistant, not a Portainer Traefik error page.

Then `make apply` in `terraform/portainer` so the compose stack is destroyed. Rollback until the next day: scale Application `hass` down, start the compose stack, move the USB stick back, point MQTT clients at `.253`. Recorder writes made on CloudNativePG after cutover are not in compose Postgres.
