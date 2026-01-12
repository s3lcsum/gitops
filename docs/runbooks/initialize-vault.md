# RB004: Initialize Vault (after recreating raft volume)

Use this runbook when Vault starts with an empty raft storage (for example after deleting/recreating the data volume), or when Vault cannot read `/vault/data/*` due to incorrect volume ownership.

## Symptoms

- Vault logs show errors like:

```text
Error initializing storage of type raft: error parsing config: open /vault/data/node-id: permission denied
```

## Quick Check

1. Confirm the container is running (or restarting) and named `vault`:

```bash
docker ps --filter "name=^vault$"
```

2. Check logs for the permission error:

```bash
docker logs vault --tail=10
```

## Resolution Steps

### 1) Fix volume ownership (Vault runs as UID/GID 100)

When the volume directory is created by root, Vault (running as user `vault` with **uid 100** and **gid 100**) may not be able to read/write raft files.

Run this once to fix permissions on the Vault data volume:

```bash
docker run --rm \
  -v vault_data:/vault/data \
  alpine \
  sh -c "chown -R 100:100 /vault/data"
```

Notes:

- If your volume is not named `vault_data`, replace it with the actual volume name (often `<compose-project>_data`).
- This runbook assumes your Vault raft path is `/vault/data` (as configured in `stacks/vault/compose.yaml`).

### 2) Start/Restart the Vault container

Bring Vault up (or restart it) after fixing permissions:

```bash
docker compose -f stacks/vault/compose.yaml up -d
```

### 3) Initialize Vault (auto-unseal configured)

If the raft storage is empty, Vault must be initialized. With auto-unseal configured, you can initialize using recovery keys:

```bash
docker exec -it vault vault operator init \
  -recovery-shares=1 \
  -recovery-threshold=1
```

**Save the output securely.** It contains the **initial root token** and **recovery key(s)**. Treat them as secrets.

## Verification

1. Check status:

```bash
docker exec -it vault vault status
```

2. Confirm logs look clean:

```bash
docker logs vault --tail=200
```

## Escalation / If This Doesn’t Work

- If you still see permission errors, re-run the ownership fix and ensure you targeted the correct Docker volume.
- If init fails with “already initialized”, stop and verify you didn’t accidentally point Vault at an existing raft directory/volume.
- If Vault stays sealed despite auto-unseal, verify your seal configuration and credentials mount in `stacks/vault/compose.yaml` (KMS access, service account file path, etc.).

