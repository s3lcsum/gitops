# Grafana Agent Configuration Notes

## Required Secrets

The Grafana Agent requires Grafana Cloud credentials. Instead of putting these in `values.yaml`, create a separate secret manifest:

### Create `grafana-cloud-secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-cloud-credentials
  namespace: grafana-agent  # or your target namespace
type: Opaque
stringData:
  # Prometheus credentials
  prometheus-url: "https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push"
  prometheus-username: "your-prometheus-username"
  prometheus-password: "your-grafana-cloud-api-key"

  # Loki credentials
  loki-url: "https://logs-prod-eu-west-0.grafana.net/loki/api/v1/push"
  loki-username: "your-loki-username"
  loki-password: "your-grafana-cloud-api-key"

  # Tempo credentials (if enabled)
  tempo-url: "https://tempo-eu-west-0.grafana.net:443"
  tempo-username: "your-tempo-username"
  tempo-password: "your-grafana-cloud-api-key"
```

### Apply the secret

```bash
kubectl apply -f grafana-cloud-secret.yaml
```

### Update values.yaml

Leave the credential fields empty in `values.yaml`:

```yaml
grafanaCloud:
  prometheus:
    enabled: true
    url: ""
    username: ""
    password: ""
  loki:
    enabled: true
    url: ""
    username: ""
    password: ""
  tempo:
    enabled: false
    url: ""
    username: ""
    password: ""
```

## Getting Your Grafana Cloud Credentials

1. Log into your Grafana Cloud account
2. Navigate to "My Account" → "API Keys"
3. Create a new API key with appropriate permissions
4. Get your endpoints from the "Details" page of each service (Prometheus, Loki, Tempo)

## Security Best Practices

- Never commit credentials to version control
- Use Kubernetes secrets or external secret management
- Rotate API keys regularly
- Use least-privilege access for API keys
