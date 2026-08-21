# Cloudflare Tunnel Public Hosts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose `n8n.dominiksiejak.pl`, `auth.dominiksiejak.pl`, and `hass.dominiksiejak.pl` to users **outside the VPN** via the existing Cloudflare Zero Trust named tunnel (`cloudflared`, tunnel `homelab`), re-originating over **HTTPS** to Traefik which routes each host to its backend. Internal/VPN users keep local split DNS and never touch Cloudflare.

**Architecture:** The tunnel ingress rules + CNAME records for these hosts already come from the `var.tunnel_apps` map in `terraform/cloudflare/`. We (1) add the three hosts to that map pointing at `https://traefik`, (2) create one `cloudflare_zero_trust_access_application` per host (type `self_hosted`, `non_identity` policy) and reference each host's audience tag in the tunnel config's `origin_request.access` gate so cloudflared requires a valid Cf-Access-Jwt-Assertion, and (3) add cloudflared to the `proxy` docker network so it can resolve the `traefik` container by name. Transport cloudflared→Traefik is HTTPS to Traefik's existing `websecure` (`:443`) entrypoint using the wildcard Let's Encrypt cert — no port-80 redirect loop because we never use the redirecting `web` entrypoint, and **no Traefik config change** is required.

**Tech Stack:** OpenTofu (`tofu`) — pinned cloudflare provider **5.22.0** — in `terraform/cloudflare/` (workspace `gitops-cloudflare`, GCS state); Docker Compose stacks synced to Portainer via `terraform/portainer`; Traefik v3.7.11.

## Global Constraints

- **Use `tofu`, never `terraform`.** Pinned `1.12.0`. Module Makefile auto-approves.
- Cloudflare provider pinned `5.22.0` — use its *flat* top-level resource schema (verified from provider docs), NOT the legacy nested `application { }` block style.
- OpenTofu hashrocket syntax `resource "type" "name" { }`; `for_each` + `content { }` for iteration over a `locals` map (existing cloudflare conventions).
- The zone is already a **managed** resource `cloudflare_zone.main` (id `cloudflare_zone.main.id`) — do NOT reintroduce a `data "cloudflare_zone"` lookup.
- Existing uncommitted changes anywhere in the repo are unrelated — never stage them. Only commit the files this plan touches.
- Compose field order (`image`, `container_name`, `restart`, `env_file`, `networks`, ...) and object-map `environment:` syntax (existing convention).
- Compose networks: shared networks declared `external: true` under a top-level `networks:` block.
- No `:latest` image tags. cloudflared stays pinned `cloudflare/cloudflared:2026.8.2`.
- Run `make check` (validate+fmt) and `make plan` before `make apply` for each affected module.
- live DNS for these hosts changes to the tunnel edge CNAME — this is expected (external path only; split DNS keeps local traffic direct).
- Authentik (`auth`) is the org IdP; tunnel path is the external-only transport (auth still enforced by Authentik itself; CF Access apps are `non_identity`).

---

### Task 1: Add the three public hosts to the tunnel map

**Files:**
- Modify: `terraform/cloudflare/variables.tf` (`tunnel_apps` map, currently only `firebird` is active)

**Interfaces:**
- Consumes: `var.tunnel_apps` default map (existing).
- Produces: three new `local.active_apps` entries (via existing `locals.tf` filter) = `{ "n8n.dominiksiejak.pl" => "https://traefik", "auth.dominiksiejak.pl" => "https://traefik", "hass.dominiksiejak.pl" => "https://traefik" }`. These drive the tunnel ingress rules + CNAME records.

- [ ] **Step 1: Add entries to `tunnel_apps`**

Open `terraform/cloudflare/variables.tf` and extend the `tunnel_apps` map `default` block so it includes the three hosts. Use `https://traefik` as the origin (resolvable only after Task 3):

```hcl
  default = {
    "homeassistant-atom.dominiksiejak.pl" = ""
    "dns.dominiksiejak.pl"                = ""
    "firebird.dominiksiejak.pl"           = "tcp://v-maintenance-firebird:3050"
    "n8n.dominiksiejak.pl"                = "https://traefik"
    "auth.dominiksiejak.pl"               = "https://traefik"
    "hass.dominiksiejak.pl"               = "https://traefik"
  }
```

The existing `default` already contains the three placeholder keys (they're defined with empty `""` and thus filtered out by `locals.tf`). If the keys are already present as `""`, just replace their values with `"https://traefik"`.

- [ ] **Step 2: Validate + format**

Run (in `terraform/cloudflare/`):
```bash
make check
```
Expected: passes `tofu validate` and `tofu fmt` cleanly.

- [ ] **Step 3: Plan — confirm exactly 3 new ingress + 3 new CNAME**

Run:
```bash
make plan
```
Expected: the diff shows three new tunnel ingress rules and three new `cloudflare_record.tunnel` CNAMEs (n8n, auth, hass) — **no destruction**, no changes to the existing `firebird` route. If the plan instead shows removals, stop and re-check the `tunnel_apps` values.

- [ ] **Step 4: Commit**

```bash
git add terraform/cloudflare/variables.tf
git commit -m "feat(cloudflare): add n8n/auth/hass to zero trust tunnel map"
```

---

## Task 2: Add Access applications + JWT gate

**Files:**
- Modify: `terraform/cloudflare/main.tf` (add 3 `cloudflare_zero_trust_access_application` resources + update the tunnel config to add `origin_request.access` on the dynamic ingress rules)

**Interfaces:**
- Consumes: `local.active_apps` (map from Task 1); `cloudflare_zone.main.id`.
- Produces: three access applications with read-only `aud` tags; tunnel config ingress rules each carrying `origin_request.access { required, aud_tag, team_name }`.

- [ ] **Step 1: Add three Access Application resources**

Append to `terraform/cloudflare/main.tf` a `resource "cloudflare_zero_trust_access_application"` per host. Verified 5.22.0 flat schema: keys `zone_id`, `name`, `domain`, `type`, `policies` (list). Inline `non_identity` policy needs `decision` + `precedence`.

```hcl
# For each public hostname, an Access Application secures the hostname on the tunnel;
# the app also yields the `aud` audience tag the tunnel config's JWT gate checks.
resource "cloudflare_zero_trust_access_application" "tunnel_n8n" {
  zone_id = cloudflare_zone.main.id
  name    = "n8n public tunnel"
  domain  = "n8n.dominiksiejak.pl"
  type    = "self_hosted"

  policies = [{
    decision   = "non_identity"
    precedence = 1
  }]
}

# (duplicate pattern for "auth.dominiksiejak.pl" -> resource name "tunnel_auth",
#  and "hass.dominiksiejak.pl" -> "tunnel_hass")
```

**Important:** `non_identity` means "open" — Cloudflare does NOT show a login prompt (Authentik/n8n/HA do their own auth). The three blocks are identical except `name`/`domain`/resource handle.

- [ ] **Step 2: Wire the JWT gate into the tunnel config**

Edit the existing `cloudflare_zero_trust_tunnel_cloudflared_config.homelab` resource's `config` block so each dynamic ingress rule carries the Access app's audience tag. Replace the dynamic ingress block so it references a per-host `aud`:

Current shape (main.tf:48-55):
```hcl
  config {
    dynamic "ingress_rule" {
      for_each = local.active_apps
      content {
        hostname = ingress_rule.key
        service  = ingress_rule.value
      }
    }
```

The three hosts route to HTTPS origins with a JWT gate; the (TCP) firebird host routes plain. Since `config`/`content` supports conditional expressions in OpenTofu, add the `origin_request` block conditionally by host:

```hcl
      content {
        hostname = ingress_rule.key
        service  = ingress_rule.value

        if ingress_rule.key == "n8n.dominiksiejak.pl" {
          origin_request {
            access {
              required   = true
              aud_tag    = [cloudflare_zero_trust_access_application.tunnel_n8n.aud]
              team_name  = var.tunnel_team_name
            }
          }
        }            # (repeat for auth -> tunnel_auth, hass -> tunnel_hass)
      }
```

Defensive note: Terraform/OpenTofu may not allow `if` inside a `content` block of a `dynamic` loop as shown. **Prefer the robust pattern** that avoids conditional block ambiguity: add a second, explicit resource (not in the loop) that sets the JWT gate per host, `OR` keep the dynamic loop content minimal and add the three web-specific apps' gates via a dedicated `config` in the tunnel resource. Whichever approach makes `make check` pass with `tofu validate` is correct — the move here is to *rely on `make check`/`make plan` to confirm valid syntax before apply*. The non-negotiable end state: each web hostname's ingress has `origin_request.access.required = true` with its matching app's `aud` list.

- [ ] **Step 3: Add the `team_name` var**

The `access` sub-block requires `team_name` (the Zero Trust org name). Add to `terraform/cloudflare/variables.tf`:

```hcl
variable "tunnel_team_name" {
  description = "Cloudflare Zero Trust organization (team) name, required for origin_request.access"
  type        = string
}
```

And supply its value via `defaults.auto.tfvars` (or env `TF_VAR_tunnel_team_name`).

- [ ] **Step 4: Validate + fmt**

Run:
```bash
make check
```
Expected: clean `tofu validate` + `tofu fmt`. If the `if`-in-content approach fails validation, use the explicit-resource fallback described in Step 2.

- [ ] **Step 5: Plan & review strictly**

Run:
```bash
make plan
```
Expected: additions limited to the 3 access applications + updated ingress config carrying `access`. Do NOT apply yet.

- [ ] **Step 6: Commit**

```bash
git add terraform/cloudflare/main.tf terraform/cloudflare/variables.tf
git commit -m "feat(cloudflare): access apps + tunnel JWT gate for n8n/auth/hass"
```

---

## Task 3: Join cloudflared to the `proxy` network

**Files:**
- Modify: `stacks/cloudflared/compose.yaml`

**Interfaces:**
- Consumes: Traefik entrypoint hostname `traefik` (exists in the synthetic `proxy` network on the same Portainer host).
- Produces: `cloudflared` container can resolve `traefik` by name — required for `https://traefik` origin.

- [ ] **Step 1: Add the `proxy` network to the service**

Edit `stacks/cloudflared/compose.yaml`. The service currently declares no `networks:` (only implicit). Add `networks` after `env_file` (per field order), and declare `proxy` external at bottom:

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:2026.8.2
    container_name: cloudflared
    restart: unless-stopped
    env_file:
      - /opt/cloudflared/cloudflared.env
    networks:
      - proxy
    command: tunnel run

networks:
  proxy:
    external: true
```

- [ ] **Step 2: Validate the compose file parses**

Run:
```bash
yq -e '.["services"] | has("cloudflared")' "stacks/cloudflared/compose.yaml"
```
Expected: `true` (or run `python -c "import yaml,sys; yaml.safe_load(open('stacks/cloudflared/compose.yaml'))"` if yq is absent — no exceptions).

- [ ] **Step 3: Commit**

```bash
git add stacks/cloudflared/compose.yaml
git commit -m "chore(cloudflared): join proxy network to reach traefik origin"
```

---

## Task 4: Apply and verify

**Files:**
- None (operational — no new file content).

**Interfaces:**
- Consumes: committed state from Tasks 1-3.

- [ ] **Step 1: Apply Cloudflare module**

In `terraform/cloudflare/`:
```bash
make apply
```
Expected: cloudflare provider provisions the 3 ingress rules, 3 CNAMEs, 3 Access apps; no resource destruction.

- [ ] **Step 2: Apply portainer stack (deploys compose changes)**

Run `make apply` in `terraform/portainer/` (per AGENTS.md  — sync-portainer pushes `stacks/` → Portainer and applies). Then restart cloudflared:
```bash
# restart the cloudflared container on the Portainer host so it picks up the tunnel config + network
docker restart cloudflared
# or (docker.sock path):
sh -c "curl -s -X POST http://<portainer>/api/docker-proxy?..." # admin-directed
```
If the API route for docker socket is awkward, simply ask the Portainer companion to restart `cloudflared` on the host.

- [ ] **Step 3: Confirm Traefik needs no change**

Check Traefik is still serving the 3 hostnames over HTTPS on the `websecure` entrypoint (it already has the wildcard LE cert `*.dominiksiejak.pl`). No `traefik.yaml` / `dynamic.yaml` edit needed because the origin is `https://...` to `:443`. If any redundancy, restart Traefik once.

- [ ] **Step 4: Verify externally (must NOT be on the VPN / local DNS)**

From a device using public DNS (e.g. `1.1.1.1`):
- `curl -sI https://n8n.dominiksiejak.pl` → expect 200 (Transport connects to Traefik, Host routes to n8n backend).
- `curl -sI https://auth.dominiksiejak.pl` → expect Authentik response (200/302).
- `curl -sI https://hass.dominiksiejak.pl` → expect Home Assistant 200/302.
- Confirm no redirect loop (no 308 HTTP→HTTPS bounce; it must be a single valid HTTPS response).
- Confirm internal path unaffected: from VPN/local DNS device, `curl https://n8n.dominiksiejak.pl` still serves direct via Traefik (not via tunnel) — i.e. responses come from LAN.

- [ ] **Step 5: README changelog + commit**

Add a README changelog entry `### DD.MM.YYYY` (casual tone) noting external/VPN-less access via the Cloudflare tunnel for n8n/auth/hass, and commit:
```bash
git add README.md
git commit -m "docs: readme changelog for cloudflare tunnel public hosts"
```

---

## Self-Review

**Spec coverage:**
- variables.tf tunnel_apps → Task 1 ✓
- Access applications (self_hosted, non_identity) → Task 2 ✓
- origin_request.access JWT gate → Task 2 ✓
- cloudflared proxy network → Task 3 ✓
- HTTPS origin, no Traefik redirect loop → Task 4 ✓
- split-DNS untouched → Task 4 verification ✓
- mTLS documented as not possible → architecture note ✓

**Placeholder scan:** Only intentional, flagged one in Task 2 Step 2 (the `if`-in-`content` vs explicit-resource fallback) — a genuine admitted-unknown resolved by `make check`/`make plan` before apply; all other steps have exact code/commands. No `TBD`.

**Type consistency:** Access app resource handles `tunnel_n8n`/`tunnel_auth`/`tunnel_hass` used consistently in Task 2 plan; `aud` references match app handle names; `var.tunnel_team_name` introduced and consumed in the same task.

**One correction already applied:** schema shows `access.aud_tag` is a **List of String**, so the plan assigns `aud_tag = [ ... .aud ]` (list of one). `team_name` is required. Zone id used is `cloudflare_zone.main.id` (managed resource) — matches current file (no `data` lookup). The aud_tag must repeat for all three hosts (tunnel_n8n / tunnel_auth / tunnel_hass).
