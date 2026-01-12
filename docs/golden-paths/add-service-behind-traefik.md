# GP004: Add a Service Behind Traefik

This guide walks you through exposing a service through Traefik, the reverse proxy.

## Prerequisites

- Traefik is running (`stacks/traefik/`)
- Your service is running (either in a Docker stack or externally)
- You've chosen a hostname for the service
- DNS is configured to point to your server (or you're using a wildcard)

## Method 1: Docker Labels (Recommended)

For services running as Docker containers, use labels in `compose.yaml`:

### Basic HTTP Service

```yaml
services:
  myservice:
    image: myimage:latest
    networks:
      - proxy
    labels:
      # Enable Traefik for this container
      - "traefik.enable=true"

      # Router configuration
      - "traefik.http.routers.myservice.rule=Host(`myservice.${DOMAIN}`)"

      # Service configuration (which port to forward to)
      - "traefik.http.services.myservice.loadbalancer.server.port=8080"

networks:
  proxy:
    external: true
```

**Key points:**

- Replace `myservice` with your service name (use same name consistently)
- Replace `8080` with the port your service listens on inside the container
- The `${DOMAIN}` variable comes from the environment

### With Authentication (Authentik Forward Auth)

Add the Authentik middleware for services that need authentication:

```yaml
labels:
  # ... basic labels from above ...

  # Add Authentik forward auth
  - "traefik.http.routers.myservice.middlewares=authentik@file"
```

The `authentik@file` middleware is defined in `stacks/traefik/dynamic.yaml`.

### With Custom Middlewares

```yaml
labels:
  # ... basic labels ...

  # Chain multiple middlewares
  - "traefik.http.routers.myservice.middlewares=secure-headers@file,authentik@file"

  # Or define inline middleware
  - "traefik.http.middlewares.myservice-ratelimit.ratelimit.average=100"
  - "traefik.http.middlewares.myservice-ratelimit.ratelimit.burst=50"
  - "traefik.http.routers.myservice.middlewares=myservice-ratelimit"
```

### Multiple Routes (e.g., API and Web)

```yaml
labels:
  - "traefik.enable=true"

  # Web UI route
  - "traefik.http.routers.myservice-web.rule=Host(`myservice.${DOMAIN}`)"
  - "traefik.http.services.myservice-web.loadbalancer.server.port=8080"

  # API route (different path)
  - "traefik.http.routers.myservice-api.rule=Host(`myservice.${DOMAIN}`) && PathPrefix(`/api`)"
  - "traefik.http.services.myservice-api.loadbalancer.server.port=8081"
```

## Method 2: File-Based Configuration

For services not running in Docker (e.g., on a different host, or a VM), use the dynamic configuration file.

Edit `stacks/traefik/dynamic.yaml`:

```yaml
http:
  routers:
    myservice:
      rule: "Host(`myservice.example.com`)"
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
      service: myservice

  services:
    myservice:
      loadBalancer:
        servers:
          - url: "http://192.168.1.50:8080"
```

Traefik watches this file and reloads automatically.

## Common Patterns

### WebSocket Support

Some services need WebSocket connections. Traefik handles this automatically, but if you have issues:

```yaml
labels:
  - "traefik.http.services.myservice.loadbalancer.server.scheme=http"
  - "traefik.http.middlewares.myservice-headers.headers.customrequestheaders.X-Forwarded-Proto=https"
```

### Redirect HTTP to HTTPS

This is handled globally in `stacks/traefik/traefik.yaml`, but for specific services:

```yaml
labels:
  # HTTP router that redirects
  - "traefik.http.routers.myservice-http.rule=Host(`myservice.${DOMAIN}`)"
  - "traefik.http.routers.myservice-http.entrypoints=web"
  - "traefik.http.routers.myservice-http.middlewares=redirect-to-https@file"

  # HTTPS router (main)
  - "traefik.http.routers.myservice.rule=Host(`myservice.${DOMAIN}`)"
  - "traefik.http.routers.myservice.entrypoints=websecure"
  - "traefik.http.routers.myservice.tls.certresolver=letsencrypt"
```

### Path-Based Routing

Route different paths to different services:

```yaml
labels:
  - "traefik.http.routers.myservice.rule=Host(`app.${DOMAIN}`) && PathPrefix(`/myservice`)"
  - "traefik.http.middlewares.myservice-strip.stripprefix.prefixes=/myservice"
  - "traefik.http.routers.myservice.middlewares=myservice-strip"
```

## Verification

After adding routing:

1. **Check Traefik dashboard**: `https://traefik.your-domain.com/dashboard/`
2. **Verify routing**: `curl -I https://myservice.your-domain.com`
3. **Check logs**: `docker logs traefik 2>&1 | grep myservice`

## Troubleshooting

| Issue | Likely Cause | Fix |
|-------|--------------|-----|
| 404 Not Found | Router not registered | Check labels syntax, ensure container is on `traefik` network |
| 502 Bad Gateway | Service unreachable | Verify port number, check service is running |
| Certificate error | Let's Encrypt issue | Check rate limits, verify DNS, check Traefik logs |
| Auth not working | Middleware not applied | Verify middleware name matches `dynamic.yaml` definition |

## Checklist

- [ ] Service is on the `traefik` network
- [ ] Labels use consistent naming (router name = service name)
- [ ] Port number matches what the service actually listens on
- [ ] DNS record exists (or wildcard is configured)
- [ ] Service appears in Traefik dashboard
- [ ] HTTPS works and certificate is valid

