# AGENTS.md — Home Infrastructure as Code

## Commands

### MkDocs (root `Makefile`)
- `make serve` — dev server `http://localhost:8000` (uses `uvx` with mkdocs-material)
- `make build` / `make lint` — strict build; fails on warnings
- `make clean` — removes `site/`
- No `mkdocs.yml` at root — config embedded in docs dir

### OpenTofu (every `terraform/<module>/`)
- Every module `Makefile` includes `terraform/base.Makefile`.
- Targets: `init`, `plan`, `apply`, `destroy`, `validate`, `fmt`, `check` (= validate + fmt), `clean`
- **Use `tofu`, not `terraform`**. Pinned version: `1.12.0` in `terraform/.opentofu-version`.
- Tofu auto-approves. Use `TOFU_ARGS` env var to pass extra flags.

### Notable module extras
- `terraform/portainer/Makefile`: `sync-portainer` rsyncs `stacks/` to `portainer:/opt`. `apply` runs sync → untaint-all → apply with `-parallelism=1`. Also `watch-portainer` (fswatch) and `sync-service` (systemd unit).
- `terraform/postgres/Makefile`: sets `POSTGRES_SSH_TARGET`, auto-creates SSH `-L` tunnel for remote plan/apply (sets `TF_VAR_postgres_host` / `TF_VAR_postgres_port`).
- `terraform/gcp/Makefile`: `state-rm-legacy` drops old resources from state. `export-vault-key` writes `vault-service-account.json` from output.
- `terraform/cloudflare/Makefile`: `show-token` prints tunnel token from output.
- `terraform/Makefile`: `migrate-all-tfc` batch-migrates all modules from TFC to GCS. `apply-all` opens each module in a tmux window.

### Pre-commit
- Run `pre-commit run --all-files` locally.
- Hooks: `tofu_fmt`, `tofu_validate`, `terraform_tflint`, plus trailing-whitespace, end-of-file-fixer, check-yaml/JSON, detect-private-key, double-quote-string-fixer.
- `check-yaml` excludes `kubernetes/**/templates/`.

## Architecture

- `stacks/` — Docker Compose stacks synced to Portainer host at `/opt/<stack>/`. Each:
  - `compose.yaml` + `*.env.example` (committed) → `*.env` (gitignored) with real secrets.
  - Traefik labels handle routing. Always `traefik.enable: true`. Only add custom hostname rule if different from `{service}.dominiksiejak.pl`.
- `terraform/` — OpenTofu modules. State: **GCS** (`dominiksiejak-gitops-tfstate`), migrated from TFC Apr 2026.
  - GCS state prefix convention: `gitops-<dirname>` (e.g., `gitops-portainer`).
- `kubernetes/` — Referenced by pre-commit exclude, present but not in README.
- `kind/` — KIND cluster configs. On the Hermes MacBook (`vibe`), cluster `hermes` runs via Colima + KIND (`kind-hermes` context). Ensure script: `~/.local/bin/kind-hermes-ensure.sh`. Ingress: Traefik (`kind/traefik-values.yaml`). Smoke: `curl -H 'Host: whoami.hermes.local' http://127.0.0.1/`. Do not talk to Portainer Docker (`ssh://portainer`) when managing this cluster.

## Networking

- Primary LAN: `192.168.89.0/24` (Portainer LXC: `192.168.89.253`)
- Auxiliary/IoT LAN: `192.168.8.0/24`
- IP allocation: `.0–.9` network devices, `.10–.99` static IPs, `.100–.199` DHCP, `.200–.254` homelab
- Internal hostname pattern: `{service}.dominiksiejak.pl`
- Public hostname pattern: `*.dominiksiejak.pl` (external IP, ports 80/443)
- Remote Docker: accessible via `ssh://portainer` (configured in `.mcp.json` Docker MCP server)

## Compose Conventions

### Field order
`image`, `container_name`, `restart`, `env_file`, `environment`, `volumes`, `networks`, `ports`, `user`, `healthcheck`, `labels`

### Env files
- **Never add `env_file:` with relative paths** — paths on host: `/opt/<stack>/<service>.env`
- **Never commit `*.env`** — gitignored globally (`**/*.env`)
- Always provide `.env.example` with same keys + placeholder values
- Use `env_file:` for secrets, `environment:` (object/map syntax) for config

### Networks
- `proxy` — external, for Traefik-exposed services
- `database` — external, for centralized PostgreSQL access
- `metrics` — external, for telemetry (optional)
- Services on multiple networks + Traefik need `traefik.docker.network: proxy`
- Define shared networks as `external: true`
- Use `expose:` over `ports:` unless host access needed

### Traefik
- Default hostname pattern: `{service}.dominiksiejak.pl`
- Public services: `*.dominiksiejak.pl` (external IP, ports 80/443)
- Traefik file routers and compose labels use a single `Host()` of `{name}.dominiksiejak.pl` (no hello/lake aliases)
- Forward-auth: `authentik@docker` on the UI. Webhooks and native-OIDC apps (HA, Seerr, Calibre-Web) stay off Authentik at the edge.
- Use object syntax for labels
- Traefik has `host.docker.internal:host-gateway` to reach host-networked services (HA, ESPHome)

### Centralized PostgreSQL
- Single Postgres stack at `stacks/postgres/`. No separate DB instances.
- **DB provisioning is managed via Terraform+Vault, not by editing init scripts.**
- New DB user: add entry to `terraform/postgres/locals.tf` + `terraform/vault/locals.tf` → apply both
- Password fetched from Vault: `vault read database/static-creds/<username>`
- Service connects via `env_file` pointing at `/opt/<stack>/<service>.env`
- Postgres is **localhost-only** on host (`127.0.0.1:5432`)
- Service needing DB must join `database` network

### Vault OIDC login from a remote machine (SSH tunnel trick)
`terraform/vault` `make auth` (and any `vault login -method=oidc`) opens a browser on the
**Mac** and listens on `localhost:8250` for the OIDC callback. If you're SSHed in from a
laptop, the browser redirect to `localhost:8250` goes nowhere on your machine. Fix:
1. On the Mac: `cd terraform/vault && make auth` — it prints an auth URL and waits.
2. On your **laptop**, open a second terminal: `ssh -L 8250:localhost:8250 vibe`
   (username + the Mac's LAN IP, e.g. `ssh -L 8250:localhost:8250 <user>@192.168.89.200`).
3. Open the printed `https://auth.dominiksiejak.pl/...` URL in your laptop browser
   (where you're already SSO-logged-in). The redirect to `localhost:8250` tunnels back
   to the Vault CLI on the Mac, which saves the token to `~/.vault-token`.

Also: `vault` CLI and `tofu` here need `VAULT_TOKEN` / `~/.vault-token` — the Vault module
has no default for `vault_token` and will prompt otherwise.

## Terraform Conventions

### File organization per module
`main.tf` (resources), `variables.tf` (sensitive vars), `locals.tf` (computed values, heavily used), `providers.tf` (provider configs), `outputs.tf` (if needed), `data.tf` (lookups), `Makefile` (automation)

### Providers
- **Pin exact versions**, never use wildcards/ranges (`~>`)
- `required_version = ">= 1.11.5"` minimum

### Code style
- Prefer `for_each` over repeated resources
- No `.sh` scripts — use Makefile for automation
- No module README files unless truly necessary
- Run `tofu fmt` and `tofu validate` after changes

## Stack Lifecycle

### Source of truth
`terraform/portainer/locals.tf` lists all actively managed stacks. **When adding/removing a stack in `stacks/`, update both `locals.tf` and `terraform/portainer/main.tf`.**

## Secrets

- **Never commit `*.env` or `*.tfvars`** — both gitignored
- `.mcp.json` contains live API tokens (HA, n8n, Cloudflare) — do not leak or commit changes exposing them
- Vault manages DB passwords (static creds). Vault access is **Traefik-only** (no host port 8200)
- Terraform variables passed via environment or `defaults.auto.tfvars`

## Verification order before big changes

1. `pre-commit run --all-files`
2. For each affected terraform module: `make check` (validate + fmt)
3. `make plan` before `make apply`

## Consistency checks

The repo has several lists that all mirror "the deployed app/host names", and they drift.
`scripts/check-consistency.py` treats **the set of hosts Traefik routes** (Docker labels in
`stacks/*/compose.yaml` + default-rule `{container}.dominiksiejak.pl` + file routers in
`stacks/traefik/dynamic.yaml`) as the single source of truth, then verifies every consumer
against it:

- **Grafana/blackbox monitors all hosts** — `stacks/monitoring/victoria-metrics/promscrape.yaml`
  `blackbox-*` jobs. **Auto-fixed** by `--fix`.
- **auth.dominiksiejak.pl shows all apps** — `terraform/authentik/locals.tf`
  (`oauth2_applications` + `proxy_applications` + `dashboard_applications`) + LDAP app in
  `ldap.tf`. **Report-only, never auto-edited** (terraform).
- **homepage.dominiksiejak.pl shows all apps + built-in integrations** —
  `stacks/homepage/config/services.yaml`. Missing entries get a stub (+ best-effort widget)
  on `--fix`; widgets present-but-missing issuance is flagged. **Auto-fixed**.
- Tertiary, report-only: `gatus/config.yaml` and README host mentions.

Usage:
- `make consistency` — dry-run report; exits non-zero on blocking drift (good for CI/pre-commit).
- `make consistency-fix` — repairs the auto-fixable YAML (blackbox + homepage), exits non-zero
  if any terraform/README issue remains for manual review.

Gotchas baked in:
- `EXTERNAL_ROUTED` = `{"portainer"}` (routed but configured outside this repo).
- `HOMEPAGE_LAN_IP` = `{nas, proxmox, router, adguard}` (homepage shows them via LAN IP, not the
  proxied host) — excluded from homepage-missing checks.
- `AUTH_NO_HTTP_ROUTE` = `{ldap}` (+ `routeros`, external) — apps with no HTTP host by design.
- A service's Traefik host comes from `container_name`, **not** the router label name
  (e.g. `hass-timemachine`, router label `timemachine`).

## n8n automation

- Instance: `https://n8n.dominiksiejak.pl`, API at `/api/v1` (disabled by default; `N8N_API_ENABLED=false`)
- UI is Authentik forward-auth (`authentik@docker`). `/webhook*` is a higher-priority Traefik router **without** Authentik (Authentik/Meta call these).
- Login → WAN allowlist: Authentik notification webhook → `stacks/n8n/workflows/authentik-login-firewall.json`. After `tofu apply` in `terraform/authentik`, copy `tofu output -raw webhook_secret` into `/opt/n8n/n8n.env` as `AUTHENTIK_WEBHOOK_SECRET`.
- Do not put RouterOS passwords in Code nodes (`N8N_BLOCK_ENV_ACCESS_IN_NODE=true`); Set node copies `$env` then Code hashes locally.
- MCP servers configured in `.mcp.json`: `n8n-mcp` (HTTP), `n8n-mcp-tools` (stdio/validation)

## Gotchas

- `terraform/portainer/locals.tf` is the source of truth for deployed stacks — README tables should match it
- Gitea: bind-mounts `/data` to NAS; needs `traefik.docker.network: proxy`
- Home Assistant stack: mosquitto has split listeners (anonymous `127.0.0.1` for HA/healthcheck; password on `192.168.89.253` for LAN and `172.17.0.1` for Docker host-gateway). Do not bind `0.0.0.0:1883` together with localhost. Create `/opt/hass/mosquitto.passwd` (uid 1883, mode 640) and `/opt/hass/mqtt.env` before sync. HA + zigbee2mqtt `depends_on` with `condition: service_healthy`; HA Time Machine behind `profile: timemachine`
- Authentik compose: Docker socket `:ro`; `AUTHENTIK_LOG_LEVEL=info`
- `stacks/postgres/init.sh` no longer exists — DB provisioning is Terraform+Vault only, not manual

## README changelog conventions

- Entries use `### DD.MM.YYYY` date header. Casual/slang tone.
- If change completes a TODO item, mark `[x]` in same commit.
- If change wasn't on TODO, add new item as `[x] (retroactively added)`.

## References

- `README.md` — full architecture, services table, changelog

## Workflow Memory

### apply-portainer
Triggers: say **"apply portainer"** OR finish editing inside `stacks/**`.

1. Run `make apply` in `terraform/portainer/`
2. Restart containers with volume-mounted configs Portainer won't auto-reload:
   - Traefik: restart `traefik` container
   - Gatus: restart `gatus` container
   - Any other mounted config files: restart affected container manually
