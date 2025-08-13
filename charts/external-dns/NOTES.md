# External-DNS Configuration Notes

## Overview

External-DNS automatically manages DNS records in Cloudflare for your Kubernetes services and ingresses. It works seamlessly with your existing Traefik ingress controller.

## How it Works with Traefik

External-DNS watches for:
1. **Ingress resources** with hostnames
2. **LoadBalancer services** (like your Traefik service)
3. **Services with external-dns annotations**

When you create an ingress with a hostname like `app.wally.dominiksiejak.pl`, external-dns will:
1. Detect the ingress
2. Find the Traefik LoadBalancer service IP
3. Create DNS records pointing `app.wally.dominiksiejak.pl` to your Traefik IP

## Required Secrets

Create a Cloudflare API token secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: external-dns
type: Opaque
stringData:
  api-token: "your-cloudflare-api-token-here"
```

### Cloudflare API Token Permissions

Your API token needs these permissions:
- **Zone:Zone:Read** - for all zones
- **Zone:DNS:Edit** - for `wally.dominiksiejak.pl`

## Example Usage

### 1. Simple Ingress (Automatic DNS)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  rules:
  - host: myapp.wally.dominiksiejak.pl  # DNS record created automatically
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
  tls:
  - hosts:
    - myapp.wally.dominiksiejak.pl
    secretName: myapp-tls
```

### 2. Service with Custom Hostname

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    external-dns.alpha.kubernetes.io/hostname: api.wally.dominiksiejak.pl
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: my-app
```

### 3. Multiple Hostnames

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-app
  annotations:
    external-dns.alpha.kubernetes.io/hostname: app1.wally.dominiksiejak.pl,app2.wally.dominiksiejak.pl
spec:
  rules:
  - host: app1.wally.dominiksiejak.pl
    # ... rules
  - host: app2.wally.dominiksiejak.pl
    # ... rules
```

## IPv6 Support

External-DNS will automatically create:
- **A records** for IPv4 addresses
- **AAAA records** for IPv6 addresses

Your Traefik LoadBalancer service will get both IPv4 and IPv6 addresses, and external-dns will create both record types.

## Monitoring

External-DNS exposes metrics on port 7979:
- `external_dns_registry_errors_total`
- `external_dns_source_endpoints_total`
- `external_dns_controller_last_sync_timestamp_seconds`

## Troubleshooting

### Check External-DNS Logs
```bash
kubectl logs -n external-dns deployment/external-dns -f
```

### Verify DNS Records
```bash
# Check if records were created
dig myapp.wally.dominiksiejak.pl
dig AAAA myapp.wally.dominiksiejak.pl
```

### Common Issues

1. **No DNS records created**: Check that your ingress has a valid hostname
2. **Wrong IP in DNS**: Verify Traefik LoadBalancer has external IP
3. **Permission errors**: Check Cloudflare API token permissions

## Integration with Existing Setup

External-DNS works alongside your existing:
- **Traefik** ingress controller
- **Cert-Manager** for TLS certificates
- **Cloudflare Tunnel** for secure access

The workflow is:
1. Create ingress with hostname
2. External-DNS creates DNS record
3. Cert-Manager gets TLS certificate
4. Traefik routes traffic
5. Cloudflare Tunnel provides secure access
