# Runbook: Traefik Routing Broken

## Symptoms

- Services returning 404 Not Found
- Services returning 502 Bad Gateway
- New services not appearing in Traefik dashboard
- SSL certificate errors
- "Service not found" in Traefik logs

## Quick Check

```bash
# Check if Traefik is running
docker ps | grep traefik

# Check Traefik logs for errors
docker logs traefik --tail 100 2>&1 | grep -E "(error|ERR|level=error)"

# Check Traefik dashboard (if accessible)
curl -s https://traefik.your-domain.com/api/http/routers | jq '.[] | .name'
```

## Resolution Steps

### Step 1: Verify Traefik Container Health

```bash
docker inspect traefik --format='{{.State.Health.Status}}'
```

If unhealthy or not running:

```bash
cd stacks/traefik
docker compose down
docker compose up -d
docker logs -f traefik
```

### Step 2: Check Docker Network

Ensure the `traefik` network exists and services are connected:

```bash
# List networks
docker network ls | grep traefik

# If missing, create it
docker network create traefik

# Check which containers are on the network
docker network inspect traefik --format='{{range .Containers}}{{.Name}} {{end}}'
```

### Step 3: Verify Service Labels

For the affected service, check its labels:

```bash
docker inspect <container-name> --format='{{json .Config.Labels}}' | jq .
```

Look for:

- `traefik.enable=true`
- `traefik.http.routers.<name>.rule=...`
- `traefik.http.services.<name>.loadbalancer.server.port=...`

### Step 4: Check Service Connectivity

```bash
# Get the service's internal IP
docker inspect <container-name> --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

# Test connectivity from Traefik
docker exec traefik wget -qO- http://<ip>:<port>/health
```

### Step 5: Check Dynamic Configuration

If using file-based routing (`stacks/traefik/dynamic.yaml`):

```bash
# Validate YAML syntax
cat stacks/traefik/dynamic.yaml | python3 -c "import yaml, sys; yaml.safe_load(sys.stdin)"

# Check Traefik loaded it
docker logs traefik 2>&1 | grep -i "dynamic"
```

### Step 6: Check Let's Encrypt / Certificates

```bash
# Check certificate resolver logs
docker logs traefik 2>&1 | grep -i "acme\|letsencrypt\|certificate"

# Check stored certificates
docker exec traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates[].domain'
```

If rate limited, wait or use staging resolver temporarily.

### Step 7: Restart Everything (Nuclear Option)

```bash
cd stacks/traefik
docker compose down
docker compose up -d

# If that doesn't work, restart Docker
sudo systemctl restart docker
```

## Verification

1. Check Traefik dashboard shows the router/service
2. `curl -I https://service.your-domain.com` returns 200
3. No errors in `docker logs traefik --tail 50`

## Escalation

If the above doesn't work:

1. Check CrowdSec isn't blocking the request: `docker logs crowdsec --tail 100`
2. Check firewall rules on the host: `sudo iptables -L -n`
3. Check DNS resolution: `dig service.your-domain.com`
4. Check Cloudflare (if using tunnel): Cloudflare dashboard > Zero Trust > Tunnels

## Common Causes

| Symptom | Likely Cause |
|---------|--------------|
| 404 on new service | Container not on `traefik` network |
| 502 Bad Gateway | Wrong port in labels, service crashed |
| Cert error | Let's Encrypt rate limit, DNS not propagated |
| Works locally, not externally | Cloudflare tunnel issue, firewall |

