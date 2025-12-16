# Runbook: Rotate Secrets

## Symptoms / Triggers

- Credential compromise suspected
- Scheduled rotation (quarterly, annually)
- Employee/access offboarding
- Secret accidentally committed to git

## Quick Check

Before rotating, identify what's affected:

```bash
# Find all .env files
find stacks/ -name "*.env" -type f

# Find all tfvars files
find terraform/ -name "*.tfvars" -type f

# Check git history for accidental commits (if compromise suspected)
git log --all --full-history -- "*.env" "*.tfvars"
```

## Resolution Steps

### Step 1: Identify Affected Secrets

Make a list of what needs rotating:

| Secret | Location | Services Using It |
|--------|----------|-------------------|
| DB password | `stacks/postgres/postgres.env` | PostgreSQL, Authentik, n8n, NetBox |
| API key | `stacks/cloudflared/cloudflared.env` | Cloudflare tunnel |
| ... | ... | ... |

### Step 2: Generate New Secrets

```bash
# Generate random password (32 chars)
openssl rand -base64 32

# Generate random hex string
openssl rand -hex 32

# Generate UUID
uuidgen
```

### Step 3: Update Database Passwords (if applicable)

For PostgreSQL:

```bash
# Connect to PostgreSQL
docker exec -it postgres psql -U postgres

# Change password for a user
ALTER USER myuser WITH PASSWORD 'new-password-here';

# Exit
\q
```

### Step 4: Update Environment Files

```bash
# Edit the .env file
vim stacks/<service>/<service>.env

# Update the secret value
# Save and exit
```

### Step 5: Restart Affected Services

```bash
# Single service
cd stacks/<service>
docker compose down
docker compose up -d

# Or via Portainer
cd terraform/portainer
make sync-portainer
# Then restart stack in Portainer UI
```

### Step 6: Update Terraform Variables (if applicable)

```bash
# For Terraform Cloud variables
# Go to app.terraform.io > Workspace > Variables > Update

# For local tfvars
vim terraform/<module>/defaults.auto.tfvars
```

### Step 7: Test Services

```bash
# Check service health
docker ps --filter "name=<service>" --format "{{.Status}}"

# Check logs for auth errors
docker logs <service> --tail 50 2>&1 | grep -i "auth\|password\|denied"

# Test actual functionality
curl -I https://service.your-domain.com
```

## Verification

- [ ] Old secret no longer works (test with old value)
- [ ] New secret works (service is functional)
- [ ] No services in crash loop
- [ ] No auth errors in logs
- [ ] Dependent services still work

## Secret-Specific Procedures

### PostgreSQL Database Password

1. Update password in PostgreSQL (Step 3)
2. Update `stacks/postgres/postgres.env`
3. Update all services that connect to this database:
   - `stacks/authentik/authentik.env`
   - `stacks/n8n/n8n.env`
   - `stacks/netbox/netbox.env`
4. Restart all affected services

### Cloudflare Tunnel Token

1. Generate new token in Cloudflare Zero Trust dashboard
2. Update `stacks/cloudflared/cloudflared.env`
3. Restart cloudflared: `docker compose restart cloudflared`

### Authentik Secret Key

1. Generate new key: `openssl rand -base64 60`
2. Update `stacks/authentik/authentik.env` (`AUTHENTIK_SECRET_KEY`)
3. Restart Authentik: `docker compose restart authentik-server authentik-worker`
4. Note: Existing sessions will be invalidated

### VPN Credentials (Gluetun)

1. Get new credentials from VPN provider
2. Update `stacks/mediabox/gluetun.env`
3. Restart mediabox stack (all containers will restart)

## Escalation

If rotation causes service outages:

1. **Rollback**: Restore old secret temporarily (if not compromised)
2. **Check dependencies**: Some services cache credentials
3. **Full restart**: `docker compose down && docker compose up -d`
4. **Check connection strings**: Ensure format is correct

## Post-Rotation

- [ ] Document rotation in changelog (if significant)
- [ ] Update any external systems using the rotated credentials
- [ ] Schedule next rotation (if periodic)
- [ ] If compromise: investigate how it happened

