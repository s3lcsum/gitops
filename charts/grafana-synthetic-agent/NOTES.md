# Grafana Synthetic Monitoring Agent

## Overview

The Grafana Synthetic Monitoring Agent enables uptime monitoring and synthetic checks for your homelab services. It connects to Grafana Cloud's Synthetic Monitoring service to run checks from your local network.

## Required Setup

### 1. Grafana Cloud Synthetic Monitoring

You need a Grafana Cloud account with Synthetic Monitoring enabled:

1. **Sign up** for Grafana Cloud (free tier available)
2. **Enable Synthetic Monitoring** in your Grafana Cloud instance
3. **Generate API Token** for Synthetic Monitoring

### 2. Get Your API Token

1. Go to your Grafana Cloud instance
2. Navigate to **Synthetic Monitoring** → **Private Probes**
3. Click **"Add Private Probe"**
4. Copy the generated **API Token**

### 3. Create API Token Secret

Create a secret with your Grafana Cloud Synthetic Monitoring API token:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: synthetic-monitoring-agent-api-token
  namespace: grafana-synthetic-agent
type: Opaque
stringData:
  api-token: "your-grafana-cloud-synthetic-monitoring-api-token"
```

Or set it directly in values.yaml (not recommended for production):

```yaml
apiToken: "your-grafana-cloud-synthetic-monitoring-api-token"
```

### 4. Update values.yaml

Set your API server region in `values.yaml`:

```yaml
grafanaCloud:
  # Choose your region's API server
  apiServerAddress: "synthetic-monitoring-grpc-eu-west.grafana.net:443"  # EU West
  # apiServerAddress: "synthetic-monitoring-grpc-us-east.grafana.net:443"  # US East
  # apiServerAddress: "synthetic-monitoring-grpc-us-west.grafana.net:443"  # US West

  # Leave empty - will be set via secret
  apiToken: ""
```

## Deployment

```bash
# Create namespace
kubectl create namespace grafana-synthetic-agent

# Create API token secret
kubectl apply -f synthetic-monitoring-secret.yaml

# Deploy the agent
helm install grafana-synthetic-agent ./charts/grafana-synthetic-agent
```

## Verification

### Check Agent Status

```bash
# Check if agent is running
kubectl get pods -n grafana-synthetic-agent

# Check agent logs
kubectl logs -n grafana-synthetic-agent deployment/grafana-synthetic-agent -f

# Check metrics endpoint
kubectl port-forward -n grafana-synthetic-agent svc/grafana-synthetic-agent 4050:4050
curl http://localhost:4050/metrics
```

### Verify in Grafana Cloud

1. Go to your Grafana Cloud instance
2. Navigate to **Synthetic Monitoring** → **Private Probes**
3. Your probe should appear as **"Online"**

## Creating Synthetic Checks

Once the agent is running, create checks in Grafana Cloud:

### 1. HTTP/HTTPS Checks

Monitor your homelab services:
- **Traefik Dashboard**: `https://traefik.lake.dominiksiejak.pl`
- **Portainer**: `https://portainer.lake.dominiksiejak.pl`
- **NetBox**: `https://netbox.lake.dominiksiejak.pl`
- **ArgoCD**: `https://argocd.lake.dominiksiejak.pl`

### 2. DNS Checks

Monitor your DNS services:
- **AdGuard DNS**: `fd89:1::53`
- **External DNS**: Check domain resolution

### 3. Ping Checks

Monitor network connectivity:
- **Proxmox Host**: `192.168.89.254`
- **Router**: `192.168.89.1`
- **NAS**: `192.168.89.210`

### 4. TCP Checks

Monitor specific services:
- **PostgreSQL**: `fd89:1::252:5432`
- **K3s API**: `fd89:2::100:6443`

## Example Check Configuration

In Grafana Cloud Synthetic Monitoring:

```json
{
  "job": "http_check_traefik",
  "target": "https://traefik.lake.dominiksiejak.pl",
  "frequency": 60000,
  "timeout": 10000,
  "probes": ["your-private-probe-id"],
  "settings": {
    "http": {
      "method": "GET",
      "validStatusCodes": [200],
      "validHTTPVersions": ["HTTP/1.1", "HTTP/2.0"],
      "followRedirects": true,
      "failIfSSL": false,
      "failIfNotSSL": true
    }
  }
}
```

## Monitoring and Alerting

### Metrics Available

The agent exposes metrics on port 4050:
- **Probe success/failure rates**
- **Response times**
- **SSL certificate expiry**
- **DNS resolution times**

### Integration with Grafana Agent

Your existing Grafana Agent can scrape synthetic monitoring metrics:

```yaml
# Add to your Grafana Agent config
prometheus.scrape "synthetic_monitoring" {
  targets = [
    { __address__ = "grafana-synthetic-agent:4050" }
  ]
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
}
```

### Alerting

Set up alerts in Grafana Cloud for:
- **Service downtime**
- **High response times**
- **SSL certificate expiry**
- **DNS resolution failures**

## Benefits for Homelab

1. **External Perspective**: Monitor services from Grafana Cloud's perspective
2. **Uptime Tracking**: Historical uptime data and SLA reporting
3. **Performance Monitoring**: Track response times and performance trends
4. **SSL Monitoring**: Get alerts before certificates expire
5. **Multi-location Checks**: Use both private probe and public probes
6. **Integration**: Works with your existing Grafana Cloud setup

## Troubleshooting

### Agent Not Connecting

1. **Check API token**: Verify token is correct and has proper permissions
2. **Network connectivity**: Ensure agent can reach Grafana Cloud
3. **Firewall**: Check if outbound HTTPS (443) is allowed

### No Metrics

1. **Check service**: Verify service is exposing port 4050
2. **Check probes**: Ensure health checks are passing
3. **Check logs**: Look for errors in agent logs

### Checks Failing

1. **Network access**: Verify agent can reach target services
2. **IPv6 connectivity**: Ensure IPv6 routing is working
3. **DNS resolution**: Check if agent can resolve hostnames

The Synthetic Monitoring Agent provides valuable external monitoring for your homelab, complementing your internal monitoring stack with uptime checks and performance monitoring from Grafana Cloud.
