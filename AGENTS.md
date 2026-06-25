# AGENTS.md — Home Infrastructure as Code

## Commands that matter

### MkDocs (root Makefile)
- `make serve` — dev server on http://localhost:8000 (uses `uvx` with mkdocs-material)
- `make build` / `make lint` — strict build; fails on warnings
- `make clean` — removes `site/`

### OpenTofu (every `terraform/<module>/`)
- Every module has a `Makefile` that includes `terraform/base.Makefile`.
- Standard targets: `init`, `plan`, `apply`, `destroy`, `validate`, `fmt`, `check` (= validate + fmt), `clean`
- **Use `tofu`, not `terraform`**. The repo switched to OpenTofu in Jan 2026.

### Notable module extras
- `terraform/portainer/Makefile`: `sync-portainer` rsyncs `stacks/` to `portainer:/opt`. The `apply` target runs sync → untaint-all → apply with `-parallelism=1`.
- `terraform/postgres/Makefile`: sets `POSTGRES_SSH_TARGET` and auto-creates an SSH `-L` tunnel for remote `plan`/`apply` (sets `TF_VAR_postgres_host` / `TF_VAR_postgres_port`).
- `terraform/gcp/Makefile`: `state-rm-legacy` drops old resources from state (orphans them in GCP). `export-vault-key` writes `vault-service-account.json` from output.
- `terraform/Makefile`: `migrate-all-tfc` batch-migrates all modules from Terraform Cloud to GCS. `apply-all` opens each module in a tmux window.

### Pre-commit
- Run `pre-commit run --all-files` locally.
- Hooks: `tofu_fmt`, `tofu_validate`, `terraform_tflint`, plus generic whitespace/YAML/JSON checks.
- `check-yaml` excludes `kubernetes/**/templates/`.

## Architecture & boundaries

- `stacks/` — Docker Compose stacks consumed by Portainer. Each stack:
  - `compose.yaml` + `*.env.example` (committed) → copy to `*.env` (gitignored) and fill secrets.
  - Traefik labels used for routing everywhere.
- `terraform/` — OpenTofu modules. State backends are **GCS** (`dominiksiejak-gitops-tfstate`), migrated from Terraform Cloud April 2026.
- `docs/` — MkDocs source; built output lives in `site/`.
- `kind/` — Two KIND clusters (`local`, `hermes`) managed declaratively via `terraform/kind/` (`tehcyx/kind` provider). Uses Podman (`KIND_EXPERIMENTAL_PROVIDER=podman`).
- `kubernetes/` — exists (referenced by pre-commit exclude). Not enumerated in README tree but present.

## Secrets & env

- **Never commit `*.env` files** — they are gitignored globally (`**/*.env`).
- **Never commit `*.tfvars`** — also gitignored.
- Terraform variables: pass via environment or `defaults.auto.tfvars` (not tracked).
- `.mcp.json` at repo root contains live API tokens (Home Assistant, n8n, Cloudflare). Do not leak or commit changes that expose them.

## Common gotchas

- `terraform/portainer/locals.tf` is the source of truth for which stacks are actively deployed — README tables should match it.
- Gitea stack: bind-mounts `/data` to NAS, not a named volume. Traefik label `traefik.docker.network: proxy` is required so it attaches to the correct network.
- Home Assistant stack:
  - `mosquitto` has a `mosquitto_sub` healthcheck.
  - HA and zigbee2mqtt use `depends_on` with `condition: service_healthy`.
- Traefik compose has `host.docker.internal:host-gateway` so file-provider routers can reach host-networked Home Assistant.
- Postgres stack is **localhost-only** (`127.0.0.1:5432`) on the host.
- Vault no longer publishes `8200` on the host — access is **Traefik-only**.
- Authentik compose: Docker socket mounted `:ro`; `AUTHENTIK_LOG_LEVEL=info`.

## Verification order before big changes

Running checks is optional—you can `make apply` directly without breaking anything, but verification saves time:

1. `pre-commit run --all-files` (catches fmt/validate/tflint issues)
2. For each affected terraform module: `make check` (validate + fmt)
3. `make lint` (docs)
4. `make plan` before `make apply`

## References

- `README.md` for full architecture, services table, and changelog.
- `kind/README.md` for cluster management commands.
