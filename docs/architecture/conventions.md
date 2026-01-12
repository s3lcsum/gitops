# A003: Coding Conventions

This page summarizes the coding standards and conventions enforced across the repository. These rules are also embedded in `.cursor/rules/` for AI-assisted development.

---

## Monorepo Structure

| Directory | Purpose |
|-----------|---------|
| `stacks/` | Docker Compose stacks (rsynced to Portainer host) |
| `terraform/` | Infrastructure as Code definitions |
| `docs/` | MkDocs documentation |

**Global constraints:**

- Minimal file creation — no auxiliary files unless absolutely required
- No standalone README.md files in subdirectories

---

## Docker Stacks (`stacks/`)

### File Layout

```
stacks/{stack_name}/
├── compose.yaml
├── {service}.env          # secrets (not committed)
└── {service}.env.example  # template (committed)
```

### Compose Field Order

Define services in this order:

1. `image` → 2. `container_name` → 3. `restart` → 4. `env_file` → 5. `environment` → 6. `volumes` → 7. `networks` → 8. `ports` → 9. `user` → 10. `healthcheck` → 11. `labels`

### Environment Variables

| Type | Where | Syntax |
|------|-------|--------|
| Secrets (passwords, tokens) | `env_file:` → `/opt/{stack}/{service}.env` | — |
| Configuration (log levels, flags) | `environment:` | Object/map syntax only |

```yaml
environment:
  LOG_LEVEL: info
  DOMAIN: example.com
```

### Networks

| Network | Usage |
|---------|-------|
| `proxy` | Traefik-exposed services (external) |
| `database` | PostgreSQL access (external) |
| `metrics` | Telemetry/observability (external, optional) |
| `{stack}_net` | Internal stack communication |

Services on `proxy` should **not** publish `ports:` — let Traefik handle ingress.

### Traefik Labels

```yaml
labels:
  traefik.enable: true
  # Only add if non-default hostname:
  traefik.http.routers.myservice.rule: Host(`custom.lake.dominiksiejak.pl`)
  # If on multiple networks:
  traefik.docker.network: proxy
```

Default domain: `{service}.lake.dominiksiejak.pl` (internal/VPN).

### PostgreSQL Access

Use the centralized `stacks/postgres/` instance — never deploy separate databases.

1. Add credentials to `stacks/postgres/postgres.env`
2. Update `stacks/postgres/init.sh` with `setup_user_and_database "$USER" "$PASS" "$DB"`
3. Reference in your stack via `postgresql://${USER}:${PASS}@postgres:5432/${DB}`

### Sync Requirement

!!! warning "Critical"
    When adding/removing a stack, update `terraform/portainer/main.tf` to keep Portainer in sync.

---

## Terraform (`terraform/`)

### File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Primary resources |
| `variables.tf` | Variable declarations (secrets/sensitive) |
| `locals.tf` | Local values, computed expressions |
| `providers.tf` | Provider configs + `terraform {}` block |
| `data.tf` | Data sources |
| `outputs.tf` | Output values (only if needed externally) |
| `Makefile` | Automation (preferred over shell scripts) |

### Provider Versions

**Always pin exact versions** — no wildcards or ranges:

```hcl
required_providers {
  authentik = {
    source  = "goauthentik/authentik"
    version = "2024.2.0"  # ✓ exact
  }
}
```

### Terraform Cloud Workspace

Naming pattern: `gitops-{submodule}`

### Variables vs Locals

| Use `variables.tf` for | Use `locals.tf` for |
|------------------------|---------------------|
| API keys/tokens | Environment configs |
| Passwords | Computed names/IDs |
| Private keys | Common tags |
| Credentials | Resource templates |

### Resources

Prefer `for_each` over duplicate resources:

```hcl
resource "example_thing" "services" {
  for_each = local.service_config
  name     = each.key
  # ...
}
```

### Modules

Only create modules when:

- `main.tf` exceeds ~100 lines
- 3+ resources required
- Logic is genuinely reusable

Place under `terraform/modules/<name>`.

### Validation

Always run after changes:

```bash
terraform fmt -recursive
terraform validate
terraform plan
```

---

## README Changelog

The root `README.md` maintains a changelog section. Entry format:

```markdown
### DD.MM.YYYY

Short, casual description of changes. Keep it concise but informative.
```

Mark TODO items complete when addressed; add retroactive items if needed.

