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
- `terraform/kind/Makefile`: overrides `destroy` to pass `-auto-approve`.
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
- `kind/` — Two KIND clusters (`local`, `hermes`) via Podman (`KIND_EXPERIMENTAL_PROVIDER=podman`). Declarative via `terraform/kind/` (tehcyx/kind provider). Run `tofu apply -var="cluster_target=local"` per machine.
- `kubernetes/` — Referenced by pre-commit exclude, present but not in README.

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
- **Always keep both `hello` and `lake` hosts** in every Traefik router rule
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

## n8n automation

- Instance: `https://nodemation.dominiksiejak.pl`, API at `/api/v1`
- MCP servers configured in `.mcp.json`: `n8n-mcp` (HTTP), `n8n-mcp-tools` (stdio/validation)
- Templates first — 2352+ available, check before building from scratch
- Validation pipeline: `validate_node(minimal)` → `validate_node(full)` → `validate_workflow`
- Never trust defaults — explicitly configure ALL parameters
- Silent execution between tool calls; respond only after all complete
- Run independent tool calls in parallel

## Gotchas

- `terraform/portainer/locals.tf` is the source of truth for deployed stacks — README tables should match it
- Gitea: bind-mounts `/data` to NAS; needs `traefik.docker.network: proxy`
- Home Assistant stack: mosquitto has `mosquitto_sub` healthcheck; HA + zigbee2mqtt `depends_on` with `condition: service_healthy`; HA Time Machine behind `profile: timemachine`
- Authentik compose: Docker socket `:ro`; `AUTHENTIK_LOG_LEVEL=info`
- `stacks/postgres/init.sh` no longer exists — DB provisioning is Terraform+Vault only, not manual

## README changelog conventions

- Entries use `### DD.MM.YYYY` date header. Casual/slang tone.
- If change completes a TODO item, mark `[x]` in same commit.
- If change wasn't on TODO, add new item as `[x] (retroactively added)`.

## References

- `README.md` — full architecture, services table, changelog
- `kind/README.md` — cluster management
