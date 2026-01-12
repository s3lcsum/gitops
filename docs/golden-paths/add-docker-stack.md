# GP002: Add a Docker Stack

This guide walks you through adding a new Docker Compose stack to the repository, following established conventions.

## Prerequisites

- The service you want to deploy has a Docker image available
- You know what ports/volumes/environment variables it needs
- You've decided on a hostname for Traefik routing (if web-accessible)

## Steps

### 1. Create the Stack Directory

```bash
mkdir stacks/<service-name>
cd stacks/<service-name>
```

Use lowercase, hyphenated names (e.g., `uptime-kuma`, `grafana-synthetic-agent`).

### 2. Create `compose.yaml`

Create the main compose file:

```yaml
services:
  <service-name>:
    image: <image>:<tag>
    container_name: <service-name>
    restart: unless-stopped
    networks:
      - proxy
    volumes:
      - <service-name>-data:/data  # or appropriate path
    environment:
      - TZ=Europe/Warsaw
    env_file:
      - /opt/<stack-name>/<service-name>.env
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.<service-name>.rule=Host(`<service-name>.${DOMAIN}`)"
      - "traefik.http.services.<service-name>.loadbalancer.server.port=<port>"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:<port>/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  proxy:
    external: true

volumes:
  <service-name>-data:
```

**Key conventions:**

- Use `restart: unless-stopped` for persistent services
- Always join the `proxy` network if web-accessible
- Set timezone to `Europe/Warsaw` (or your preference)
- Add healthchecks when possible
- Use named volumes, not bind mounts (unless required)

### 3. Create Environment Example File

If the service needs environment variables, create `<service-name>.env.example`:

```bash
# <service-name>.env.example
# Copy to <service-name>.env and fill in values

# Required
DB_PASSWORD=changeme
API_KEY=your-api-key-here
```

**Rules:**

- Never commit real secrets
- Use `changeme` or descriptive placeholders
- Group required vs optional variables
- Add comments explaining each variable
- Use .env file only for more sensitive values like API_TOKENS or PASSWORD or SMTP configuration
- Use `environments:` for non sensitive configuration like LOG_LEVEL, EXTERNAL_URL, etc.

### 4. Update compose.yaml to Use Environment File

```yaml
services:
  <service-name>:
    # ... other config ...
    env_file:
      - /opt/<stack-name>/<service-name>.env
```

### 5. Add to .gitignore (if not already)

Ensure `*.env` files are ignored:

```gitignore
# Environment files with secrets
*.env
!*.env.example
```

### 6. Test Locally

```bash
cd stacks/<service-name>
cp <service-name>.env.example <service-name>.env
# Edit <service-name>.env with real values
docker compose up -d
docker compose logs -f
```

### 7. Deploy via Portainer

The `terraform/portainer/` module syncs stacks to the Portainer host:

```bash
cd terraform/portainer
make sync-portainer  # rsync stacks to host
make apply           # update Portainer configuration
```

Or use Portainer's UI to add the stack manually.

## Checklist

Before committing:

- [ ] `compose.yaml` follows naming conventions
- [ ] Environment example file created (if needed)
- [ ] Traefik labels configured correctly
- [ ] Healthcheck added (if possible)
- [ ] Service starts without errors
- [ ] No secrets in committed files

## Examples

Look at existing stacks for reference:

- Simple service: `stacks/dozzle/`
- Service with database: `stacks/n8n/`
- Service with VPN routing: `stacks/mediabox/`
- Service with multiple containers: `stacks/authentik/`

