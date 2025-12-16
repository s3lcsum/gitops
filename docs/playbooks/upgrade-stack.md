# Playbook: Upgrade a Stack

## Purpose

Safely update a Docker service to a newer version with minimal downtime and a clear rollback path.

## Prerequisites

- [ ] Know which service you're upgrading
- [ ] Know the target version (check release notes!)
- [ ] Recent backup exists (if service has persistent data)
- [ ] Maintenance window scheduled (if critical service)

## Estimated Time

15-30 minutes (depending on service complexity)

## Procedure

### 1. Review Release Notes

Before upgrading, check:

- Breaking changes
- Required migration steps
- New environment variables
- Database schema changes

```bash
# Example: Check releases on GitHub
open https://github.com/<org>/<repo>/releases
```

### 2. Document Current State

```bash
cd stacks/<service>

# Record current image version
docker inspect <service> --format='{{.Config.Image}}'

# Record current config
cat compose.yaml
cat *.env  # Don't commit this output anywhere!

# Check current health
docker ps --filter "name=<service>"
```

### 3. Backup Data (if applicable)

```bash
# For services with volumes
docker run --rm -v <service>-data:/data -v $(pwd):/backup alpine \
  tar czf /backup/<service>-backup-$(date +%Y%m%d).tar.gz /data

# For databases
docker exec postgres pg_dump -U postgres <database> > backup.sql
```

### 4. Update compose.yaml

```bash
# Edit the image tag
vim compose.yaml

# Change:
#   image: service:1.0.0
# To:
#   image: service:1.1.0
```

**Best practice**: Use specific version tags, not `latest`.

### 5. Pull New Image

```bash
docker compose pull
```

### 6. Stop Current Service

```bash
docker compose down
```

### 7. Start Updated Service

```bash
docker compose up -d
```

### 8. Monitor Startup

```bash
# Watch logs
docker compose logs -f

# Check health
docker ps --filter "name=<service>"

# Wait for healthy status
watch -n 2 'docker ps --filter "name=<service>" --format "{{.Status}}"'
```

### 9. Verify Functionality

- [ ] Service responds on expected URL
- [ ] Login works (if applicable)
- [ ] Core functionality works
- [ ] No errors in logs
- [ ] Dependent services still work

```bash
# Quick health check
curl -I https://<service>.your-domain.com

# Check for errors
docker logs <service> 2>&1 | grep -i "error\|exception\|fatal"
```

### 10. Sync to Portainer (if using)

```bash
cd terraform/portainer
make sync-portainer
```

## Rollback Procedure

If something goes wrong:

### Quick Rollback

```bash
cd stacks/<service>

# Revert compose.yaml to old version
git checkout compose.yaml
# Or manually edit back to old image tag

# Restart with old version
docker compose down
docker compose up -d
```

### If Data Migration Happened

```bash
# Stop the service
docker compose down

# Restore data backup
docker run --rm -v <service>-data:/data -v $(pwd):/backup alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/<service>-backup-*.tar.gz -C /"

# Restore database
docker exec -i postgres psql -U postgres <database> < backup.sql

# Start old version
docker compose up -d
```

## Post-Upgrade

- [ ] Delete old backup (after confirming stability)
- [ ] Update any documentation if config changed
- [ ] Note the upgrade in changelog (if significant)
- [ ] Monitor for issues over next 24-48 hours

## Service-Specific Notes

### Authentik

- Check for flow/stage migrations
- May need to run migrations manually: `docker exec authentik-server ak migrate`
- Clear browser cache after upgrade

### PostgreSQL

- Minor version upgrades: usually safe
- Major version upgrades: require `pg_upgrade` or dump/restore
- Always backup before upgrading

### Traefik

- Check for config file format changes
- May need to update `traefik.yaml` or `dynamic.yaml`
- Test with `docker compose config` before applying

### Media Stack (Sonarr/Radarr/etc)

- These often have database migrations
- Let them complete before using
- Check Settings > System > Updates after restart

