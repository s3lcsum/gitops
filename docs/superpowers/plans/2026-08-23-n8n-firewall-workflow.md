# Phone Firewall Page — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy `https://enter.dominiksiejak.pl` — a phone-friendly page behind Authentik SSO where any authenticated user adds their IP to the RouterOS `allowed-wan` firewall address list with a 1d/7d/30d TTL.

**Architecture:** Traefik routes the `enter.` hostname through the existing `authentik@docker` forward-auth middleware into n8n. Two n8n workflows serve the HTML page (`GET /webhook/firewall-page`) and accept additions (`POST /webhook/firewall`). A scheduled n8n workflow garbage-collects expired `ttl:`-tagged entries via the RouterOS REST API. n8n stores RouterOS credentials as env vars and trusts the Authentik `X-Authentik-*` forwarded headers.

**Tech Stack:** n8n 2.35.7 (ghcr.io/n8n-io/n8n), Traefik 3.7.10, Authentik 2026.8.0, MikroTik RouterOS (REST API), Terraform/OpenTofu for Authentik, Docker Compose.

## Global Constraints

- All Authentik provider/apps for proxy applications are defined in `terraform/authentik/` (locals.tf + applications.tf) — codify the `enter` app there, run `tofu plan`/`apply` from `terraform/authentik`.
- Traefik routing for non-Docker services lives in `stacks/traefik/dynamic.yaml`; every Traefik router rule keeps both `hello` and `lake` hosts. n8n is a Docker container reachable on the `proxy` network.
- Composer conventions: labels use object syntax, no committed `*.env`, always update `*.env.example` with placeholder keys.
- RouterOS REST API (verified): create = `PUT /rest/ip/firewall/address-list` `{"address","list","comment","disabled"}`, list = `GET .../address-list`, delete = `DELETE .../address-list/` + raw `.id` (do NOT URL-encode `*`).
- The firewall webhooks (`/webhook/firewall*`) must be reachable ONLY via `enter.dominiksiejak.pl`, and the regular `n8n.dominiksiejak.pl` host must block those paths to prevent `X-Authentik-*` header spoofing.
- Respond to Webhook (GET page) must return `Content-Type: text/html`.
- Approx cost: no new container — reuse n8n + Traefik.

---
## File Structure

| File | Responsibility |
|---|---|
| `stacks/traefik/dynamic.yaml` | Add `enter` router + blank X-Authentik headers on `n8n.` `/webhook` |
| `terraform/authentik/locals.tf` | Add `enter` proxy application entry (any-user) |
| `terraform/authentik/applications.tf` | No change needed (proxy apps auto-templated) |
| `stacks/n8n/n8n.env` / `.example` | RouterOS API creds (`ROUTEROS_API_*`) |
| `stacks/n8n/firewall-page.html` | The phone-friendly HTML page source (pasted into workflow A's HTML block) |
| n8n UI | Workflow A (serve page), Workflow B (add IP), Workflow C (cleanup) |

## Task Order

1. RouterOS API credentials → n8n env vars
2. HTML page source file
3. n8n Workflow C (cleanup) — simplest, no auth
4. n8n Workflow B (add IP) — core, checks auth + IP + calls RouterOS
5. n8n Workflow A (serve page)
6. Traefik routing (`enter`, block firewall paths on `n8n.`)
7. Authentik proxy app `enter` (Terraform)
8. Apply + end-to-end verification

---

### Task 1: Add RouterOS credentials to n8n env

**Files:**
- Modify: `stacks/n8n/n8n.env` (secrets, gitignored)
- Modify: `stacks/n8n/n8n.env.example` (placeholders)
- Modify: `stacks/n8n/compose.yaml` (no change — env_file already loads `/opt/n8n/n8n.env`; confirm)

**Interfaces:**
- Consumes: nothing.
- Produces: n8n env vars `ROUTEROS_API_URL`, `ROUTEROS_API_USER`, `ROUTEROS_API_PASS` available to all workflows.

- [ ] **Step 1: Read current n8n.env to see existing secrets**

Run: `grep -vE "PASSWORD|SECRET|TOKEN|KEY" /Users/Apple/Developer/s3lcsum/gitops/stacks/n8n/n8n.env`
Expected: existing env lines (API enabled, DB, Telegram) with no secrets shown.

- [ ] **Step 2: Add RouterOS vars to n8n.env (local, gitignored)**

Append to `stacks/n8n/n8n.env`:
```ini
ROUTEROS_API_URL=https://router.dominiksiejak.pl/rest
ROUTEROS_API_USER=terraform
ROUTEROS_API_PASS=<value from terraform/routeros/defaults.auto.tfvars>
```
(The exact password is in `/Users/linux/Developer/s3dsum/gitops/terraform/routeros/defaults.auto.tfvars`; copy it. `terraform` already has write perms to the address-list — verified in prev steps.)

- [ ] **Step 3: Add placeholders to n8n.env.example**

Append to `stacks/n8n/n8n.env.example`:
```ini
ROUTEROS_API_URL=https://router.dominiksiejak.pl/rest
ROUTEROS_API_USER=your_routeros_api_user_here
ROUTEROS_API_PASS=your_routeros_api_password_here
```

- [ ] **Step 4: Validate compose.yaml uses env_file (no change needed)**

Run: `grep -n "env_file\|ROUTEROS" stacks/n8n/compose.yaml`
Expected: line with `env_file:` pointing to `/opt/n8n/n8n.env`. No ROUTEROS lines.

- [ ] **Step 5: Commit**

```bash
git add stacks/n8n/n8n.env.example
git commit -m "feat(n8n): declare RouterOS API env placeholders for firewall workflow"
```
(Do NOT stage `n8n.env` — it is gitignored. `git add` above only adds the `.example`.)

---

### Task 2: Create the phone-friendly HTML page source

**Files:**
- Create: `stacks/n8n/firewall-page.html`

**Interfaces:**
- Consumes: nothing (self-contained inline CSS/JS).
- Produces: `firewall-page.html` whose contents get pasted into Workflow A's HTML response. Posts JSON to `POST /webhook/firewall` (same origin).

- [ ] **Step 1: Write the HTML page (single, valid draft)**

Create `stacks/n8n/firewall-page.html` exactly:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Add IP to Firewall</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { font-family: system-ui, -apple-system, sans-serif; background:#0b1220; color:#e6e6e6;
         display:flex; align-items:center; justify-content:center; min-height:100vh;
         margin:0; padding:16px; }
  .card { background:#1e2030; border:1px solid #2a3a5a; border-radius:16px;
          padding:24px; width:100%; max-width:380px; box-shadow:0 8px 24px rgba(0,0,0,.4); }
  h1 { font-size:1.25rem; margin:0 0 4px; }
  .who { font-size:.85rem; color:#9fb3d1; margin-bottom:16px; }
  label { display:block; font-size:.85rem; color:#9fb3d1; margin:14px 0 6px; }
  input { width:100%; padding:12px; border:1px solid #3a4a6a; border-radius:10px;
          background:#12203c; color:#e6e6e6; font-size:1rem; }
  .ttls { display:flex; gap:8px; }
  .ttl { flex:1; padding:12px; border:1px solid #3a4a6a; border-radius:10px;
         background:#12203c; color:#e6e6e6; font-size:1rem; cursor:pointer; transition:.1s; }
  .ttl.sel { background:#2f6fed; color:#fff; border-color:#2f6fed; }
  button.submit { width:100%; padding:12px; border:none; border-radius:12px;
            background:#2f6fed; color:#fff; font-weight:600; font-size:1rem;
            cursor:pointer; margin-top:20px; }
  .msg { margin-top:14px; padding:10px; border-radius:8px; font-size:.9rem;
         white-space:pre-line; display:none; }
  .msg.ok { display:block; background:#132b1e; color:#7ee2a8; border:1px solid #1f6b3a; }
  .msg.err { display:block; background:#3b1212; color:#f88; border:1px solid #8b1a1a; }
</style>
</head>
<body>
<div class="card">
  <h1>&#128293; Add IP to Firewall</h1>
  <div class="who">Logged in as: <b>__NAME__</b></div>
  <label for="ip">IP Address</label>
  <input id="ip" value="" placeholder="Detecting your IP…">
  <label>Time to Live</label>
  <div class="ttls">
    <button type="button" class="ttl" data-ttl="1d">1d</button>
    <button type="button" class="ttl sel" data-ttl="7d">7d</button>
    <button type="button" class="ttl" data-ttl="30d">30d</button>
  </div>
  <button class="submit" id="submit" type="button">Add to Firewall</button>
  <div class="msg" id="msg"></div>
</div>
<script>
  let ttl = "7d";
  const $ = id => document.getElementById(id);
  const setMsg = (ok, txt) => { const m = $("msg"); m.className = ok ? "msg ok" : "msg err"; m.textContent = txt; };
  (async () => {
    try {
      const j = await (await fetch("https://api.ipify.org?format=json")).json();
      if (j.ip) { $("ip").value = j.ip; } else { $("ip").placeholder = "Enter your IP"; }
    } catch (e) { $("ip").placeholder = "Enter your IP"; }
  })();
  document.querySelectorAll(".ttl").forEach(b => {
    b.onclick = () => {
      document.querySelectorAll(".ttl").forEach(x => x.classList.remove("sel"));
      b.classList.add("sel"); ttl = b.dataset.ttl;
    };
  });
  $("submit").onclick = async () => {
    const ip = $("ip").value.trim();
    if (!ip) { setMsg(false, "Enter your IP."); return; }
    setMsg(true, "Adding…");
    try {
      const res = await fetch("/webhook/firewall", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ip, ttl })
      });
      const j = await res.json();
      if (j.ok) { setMsg(true, "Added! Expires " + j.expires); }
      else { setMsg(false, j.detail || "Request failed"); }
    } catch (e) { setMsg(false, "Network error: " + e.message); }
  };
</script>
</body>
</html>
```

The `__NAME__` placeholder is replaced server-side by Workflow A (Task 5).

- [ ] **Step 2: Sanity-check the HTML**

Run: `python3 -c "print('ok')"` — no Java/Node available needed; the page has no server dependency. Confirm the file contains exactly one `__NAME__` placeholder:
`grep -c '__NAME__' stacks/n8n/firewall-page.html` → `1`

- [ ] **Step 3: Commit**

```bash
git add stacks/n8n/firewall-page.html
git commit -m "feat(n8n): add phone-friendly firewall allowlist page source"
```

---

### Task 3: n8n Workflow C — Cleanup expired entries

**Files:**
- Create (via n8n UI or MCP): workflow named "Firewall Cleanup", active, scheduled every 5 min.
- Test: manual trigger; verify expired removed.

**Interfaces:**
- Consumes: env `ROUTEROS_API_URL/USER/PASS` (Task 1).
- Produces: idempotent cleanup of `ttl:` entries with `comment` timestamp before now.

- [ ] **Step 1: Create the workflow with Schedule trigger**

In n8n UI: add **Schedule Trigger** → Interval → “every 5 minutes”.
Wire: Schedule → HTTP Request (`List`) → **Run Once for All Items** set ON → Code (filter) → Loop → HTTP Request (delete) → (optional) Log.

- [ ] **Step 2: HTTP GET list**

HTTP Request node (list):
- Method: GET
- URL: `{{ $env.ROUTEROS_API_URL }}/ip/firewall/address-list`
- Authentication: Generic Header; Base64 `ROUTEROS_API_USER:ROUTEROS_API_PASS` → `Authorization: Basic <base64>`.
Expected output: array of entries with `.id`, `address`, `list`, `comment`.

- [ ] **Step 3: Code node — filter expired**

Add a Code node after the list, set Processing mode to “Run Once for All Items”, with:
```js
// entries are in the JSON array at $input.all()[0].json
const listName = "allowed-wan";
const now = Date.now();
const items = $input.all()[0].json;          // array from the GET response
const expired = items.filter(e => {
  if (e.list !== listName) return false;
  const m = (e.comment || "").match(/^ttl:(\d+)$/);
  return m && Number(m[1]) < now;
}).map(e => ({ id: e[".id"], address: e.address }));
return expired;  // array of {id, address}
```
Verify field casing matches the actual API response after the first manual run (`.id` keys come through as `'.id'`).

- [ ] **Step 4: For-loop over filtered, DELETE each**

Loop node: iterate the array from the Code node.
HTTP Request (delete) inside the loop:
- Method: `DELETE`
- URL: `{{ $env.ROUTEROS_API_URL }}/ip/firewall/address-list/{{ $json.id }}`
- **Critical:** n8n's HTTP Request node URL-encodes path segments. The RouterOS `.id` value is `*5B3` and the `*` must NOT be `%2A`-encoded (encode breaks delete — verified: `DELETE .../address-list/*5B3` = 204, `%2A5B3` = 400). Workaround: in the HTTP Request node set the URL with the id already “double-escaped”, or use the node’s **Options → “Allow (path) special chars”** / “Disable URL encode”. Confirm `204` (not `400`) in the execution output.

- [ ] **Step 5: Test the workflow**

Run: trigger the workflow manually (n8n → “Execute workflow”). Then verify with:
`curl -u USER:PASS "https://router.dominiksiejak.pl/rest/ip/firewall/address-list"` → confirm the expired test entry (if any) is gone and live entries remain (neither of the two persistent allowed-wan entries removed).

- [ ] **Step 6: Commit (export workflow JSON into repo)**

Export workflow JSON and save to `stacks/n8n/workflows/firewall-cleanup.json`.

```bash
git add stacks/n8n/workflows/firewall-cleanup.json
git commit -m "feat(n8n): firewall cleanup schedule workflow"
```

---

### Task 4: n8n Workflow B — Add IP to firewall

**Files:**
- Create (via n8n UI/MCP): `firewall-add` workflow.
- Export CSV/JSON to `stacks/n8n/workflows/firewall-add.json`.

**Interfaces:**
- Consumes: env creds (Task 1); inbound POST body `{ip, ttl}`; Authentik headers `X-Authentik-*` set by Traefik (Task 6).
- Produces: Respond to Webhook JSON `{ok, ip, expires, detail?}`; RouterOS address-list entry with `comment: ttl:<unix_ms>`.

- [ ] **Step 1: Webhook trigger**

Webhook (POST) `/webhook/firewall`. Path: `firewall`. Method POST. Response mode = Respond to webhook.

- [ ] **Step 2: Auth check (all authenticated users allowed, but no anonymous)**

IF node: condition on `$json.headers['x-authentik-uid']` presence (the forward-auth sets `X-Authentik-*`). If absent → respond 403 with `{ok:false, detail:"Unauthenticated"}`.
Note: because the public `n8n.dominiksiejak.pl/webhook/*` path blanks `X-Authentik-*` (Task 6), the only origin that can present genuine Authentik headers is the `enter.` host — spoofed headers arriving on the n8n host get stripped before reaching n8n.

- [ ] **Step 3: Validate IP**

IF node: match `$json.ip` against IPv4 regex `^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$` and range-check each octet 0-255. Invalid → 400 `{ok:false, detail:"Invalid IP"}`.

- [ ] **Step 4: Compute expiry**

Code node: input ip + ttl(1d/7d/30d) → output `expires_ms` (now + ttl) and ISO string.

- [ ] **Step 5: HTTP PUT to RouterOS**

HTTP Request node (create):
- Method: PUT
- URL: `{{ $env.ROUTEROS_API_URL }}/ip/firewall/address-list`
- Body (JSON): `{ "address": "{{ $json.ip }}", "list": "allowed-wan", "comment": "ttl:{{ $json.expires_ms }}", "disabled": false }`
- Authentication: Generic Header; Base64 `ROUTEROS_API_USER:ROUTEROS_API_PASS`.

Note on `$env.ROUTEROS_API_URL`: n8n reads env vars via `$env.VAR`. If the workflow is edited for readability, keep the dot syntax consistent throughout.

- [ ] **Step 6: Respond to webhook on success**

Respond: `{ ok:true, ip:"...", expires:"<ISO>" , detail:"Added to allowed-wan until <ISO>" }`

- [ ] **Step 7: Error branch — respond 500**

If HTTP PUT fails, branch to a Respond node `{ ok:false, detail:"Router error: <status>" }`.

- [ ] **Step 8: Export workflow JSON to repo**

```bash
git add stacks/n8n/workflows/firewall-add.json
git commit -m "feat(n8n): add IP to RouterOS firewall workflow"
```

---

### Task 5: n8n Workflow A — Serve the firewall page

**Files:**
- Create (via n8n UI/MCP): `firewall-page` workflow.
- Source: `stacks/n8n/firewall-page.html` (Task 2) with `__NAME__` replaced by Authentik name header at runtime.

**Interfaces:**
- Consumes: the HTML file (Task 2); Authentik header `X-Authentik-Name`.
- Produces: `200 text/html` page.

- [ ] **Step 1: Webhook trigger GET**

Webhook node: path `firewall-page`, method GET, response = Respond.

- [ ] **Step 2: Embed the HTML in a Code node**

The n8n Code node runs inside the n8n container and cannot read the host repo file `stacks/n8n/firewall-page.html`. So embed the file's content directly as a string in the Code node:

Code node (Run Once for All Items), `html` variable = the exact contents of `stacks/n8n/firewall-page.html` (Task 2) pasted into a backtick string:
```js
const html = `<paste full firewall-page.html here>`;
const name = ($json.headers && ($json.headers["x-authentik-name"] || $json.headers["X-Authentik-Name"])) || "user";
return { rendered: html.replace("__NAME__", name) };
```
(Use a backtick template literal; escape any backticks/`${}` inside the HTML so it survives n8n's editor.)

- [ ] **Step 3: Respond with text/html**

Respond to Webhook node:
- status 200
- header `Content-Type: text/html`
- body = `{{ $json.rendered }}`

- [ ] **Step 4: Export + commit**

```bash
git add stacks/n8n/workflows/firewall-page.json
git commit -m "feat(n8n): serve phone firewall page workflow"
```

---

### Task 6: Traefik routing — `enter` host + block firewall paths on `n8n`

**Files:**
- Modify: `stacks/traefik/dynamic.yaml` (add router `enter` + blank inbound `X-Authentik-*` on the n8n `/webhook` path).

**Interfaces:**
- Produces: `enter.dominiksiejak.pl` reachable only via Authentik; `n8n.dominiksiejak.pl/webhook/*` gets `X-Authentik-*` headers blanked (spoof-proof).

- [ ] **Step 1: Read current dynamic.yaml**

Run: `read stacks/traefik/dynamic.yaml` (confirm both `hello` and `lake` hosts; confirm `authentik@docker` middleware exists).
The docker default rule `Host(n8n…)` auto-routes n8n with **no** authentik middleware — that's why we must add an explicit router for the firewall path on that host.

- [ ] **Step 2: Add the `enter` router to dynamic.yaml**

Add under `routers:` (the n8n container is a docker service, referenced as `n8n@docker`):
```yaml
    enter:
      rule: "Host(`enter.dominiksiejak.pl`)"
      entryPoints:
        - websecure
      middlewares:
        - authentik@docker
      service: n8n@docker
```

- [ ] **Step 3: Add the spoof-proof router for `/webhook/firewall*` on the n8n host**

Background: the only origin for the POST that must carry Authentik headers is `enter.`. If someone directly hits `n8n.dominiksiejak.pl/webhook/firewall` (the docker auto-rule has no middleware), the header would be absent → n8n responds 403. The residual risk is a forged header arriving on the public n8n host. To close it, add a middleware that **blanks inbound `X-Authentik-*`** and attach it to the n8n `/webhook/*` path via a file router with higher priority.

Add under `middlewares`:
```yaml
    strip-authentik:
      headers:
        customRequestHeaders:
          X-Authentik-User: ""
          X-Authentik-Name: ""
          X-Authentik-Email: ""
          X-Authentik-Uid: ""
          X-Authentik-Groups: ""
          X-Authentik-Username: ""
          X-Authentik-Entitlements: ""
          X-Authentik-Jwt: ""
```
Add a router that takes precedence over the docker default for `/webhook/*`:
```yaml
    n8n-webhook:
      rule: "Host(`n8n.dominiksiejak.pl`) && PathPrefix(`/webhook`)"
      entryPoints:
        - websecure
      priority: 200   # beats docker default rule for this host
      middlewares:
        - strip-authentik
      service: n8n@docker
```
Rationale: For `Host(n8n.*)` + `/webhook/*`, Traefik picks the more specific file router (higher priority) → strips any client-supplied `X-Authentik-*` before they reach n8n. Only the `enter.` router (behind the Authentik forward-auth middleware, which sets its own `X-Authentik-*` from the verified session) carries genuine headers.

- [ ] **Step 4: Validate YAML**

Run: `python3 -c "import yaml,sys;yaml.safe_load(open('stacks/traefik/dynamic.yaml'))"`
Expected: no error.

- [ ] **Step 5: Commit**

```bash
git add stacks/traefik/dynamic.yaml
git commit -m "feat(traefik): route enter firewall page behind authentik, strip x-authentik on n8n webhook"
```

---

### Task 7: Authentik proxy app `enter` (Terraform)

**Files:**
- Modify: `terraform/authentik/locals.tf` (add proxy_applications entry `enter`).
- Possibly: no application.tf change needed (proxy apps auto). Confirm.

**Interfaces:**
- Consumes: existing `authentik_provider_proxy` for_each.
- Produces: Authentik `enter` app, user-accessible (it must not be restricted to admins only).

- [ ] **Step 1: Read locals.tf proxy_applications block**

- [ ] **Step 2: Add enter entry**

```hcl
    enter = {
      name            = "Firewall Access"
      external_host   = "https://enter.dominiksiejak.pl"
      internal_host   = "http://n8n:5678"
      launch_url      = "https://enter.dominiksiejak.pl"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/firewall.svg"
      skip_path_regex = ""
    }
```
(`internal_host` matches the existing pattern: `victoriametrics` → `http://monitoring:8428`, so n8n → `http://n8n:5678`. Confirm `n8n` is the container_name from `stacks/n8n/compose.yaml`.)

- [ ] **Step 3: Make it user-accessible (not admin-only)**

The Authentik access bindings in `terraform/authentik/applications.tf` gate `admin_access` (admins group) on `all_app_uuids` and also bind `user_access` for apps listed in `local.user_accessible_apps`. To let any user reach `enter`, add it to the `user_accessible_apps` set in `terraform/authentik/locals.tf`:
```hcl
  user_accessible_apps = toset([
    ...,
    "enter",
  ])
```

- [ ] **Step 4: Run tofu validate + fmt + plan + apply**

```bash
cd terraform/authentik
make init
tofu fmt -check && tofu validate
tofu plan
make apply
```
Expect: creates `enter` proxy provider + application; no errors. (Note: the module `Makefile` only defines `init`/`plan`/`apply` — there is no `make validate`/`make fmt`; run `tofu` directly for fmt/validate.)

- [ ] **Step 5: Verify app in Authentik UI (optionally)**

- [ ] **Step 6: Commit**

```bash
git add terraform/authentik/locals.tf
git commit -m "feat(authentik): add enter firewall proxy application, user-accessible"
```

---

### Task 8: Deploy + end-to-end verification

**Files:**
- Modify: none (apply Traefik via portainer stack sync or docker compose).

**Interfaces:**
- Consumes: all previous task outputs.
- Produces: live `enter.dominiksiejak.pl`.

- [ ] **Step 1: Sync traefik config + restart**

Deploy `stacks/traefik/dynamic.yaml` to portainer host (`/opt/traefik/dynamic.yaml`) and restart `traefik` container. `make sync-service` in terraform/portainer or `make apply`.

- [ ] **Step 2: Restart n8n to load new env**

Restart the n8n container so `ROUTEROS_API_*` env vars load. (n8n.env already referenced by env_file; restart picks up.)

- [ ] **Step 3: Retrieve n8n webhook URLs**

In the n8n UI, copy Production webhook URLs for both workflows. Expected:
- `https://enter.dominiksiejak.pl/webhook/firewall-page` (GET)
- `https://enter.dominiksiejak.pl/webhook/firewall` (POST)

- [ ] **Step 4: Verify page loads unauth → redirects to auth**

Visit `https://enter.dominiksiejak.pl/webhook/firewall-page` incognito: expect Authentik login redirect (302 to auth.dominiksiejak.pl), NOT 200 HTML.

- [ ] **Step 5: Authenticate and load page**

Log in as any user → page 200, correct content type text/html, IP auto-detected, name shown.

- [ ] **Step 6: Submit → verify RouterOS entry**

Click with 1d. Then:
```bash
curl -u USER:PASS "https://router.dominiksiejak.pl/rest/ip/firewall/address-list?list=allowed-wan"
```
Confirm new IP present with `comment":"ttl:<now+1d ms>`.

- [ ] **Step 7: Verify cleanup removes expired (set tiny TTL to test)**

Temporarily create an entry with `ttl:1000` (past) via curl; wait ≤5 min for the schedule; confirm removed. Reset to normal TTLs after.

- [ ] **Step 8: Verify /webhook blocked on the n8n host**

```bash
curl -sk -X POST https://n8n.dominiksiejak.pl/webhook/firewall -H 'Content-Type: application/json' -d '{"ip":"8.8.8.8","ttl":"1d"}'
```
Expected: 403 (no authentik header), NOT a new firewall entry.

- [ ] **Step 9: Commit any workflow-export files + plan doc**

```bash
git add docs/superpowers/plans/2026-08-23-n8n-functional-firewall.md
git add stacks/traefik/dynamic.yaml stacks/n8n/n8n.env.example
git commit -m "feat(firewall): phone page to add IP to allowed-wan"
```

---

## Self-Review Notes

- Verified RouterOS REST create (PUT returns id), list, delete (raw `*` id) on the live router; test entry cleaned up so live state unchanged.
- Shared-secret removed per design; trust pivots to Authentik headers + stripping inbound X-Authentik-* on the non-proxied n8n host.
- The firewall webhook paths are blocked on the plain n8n host / other routes; only `enter.` (Authentik-gated) can reach them.
- Health: the `enter.` route must appear in Traefik; the `enter` router references the n8n docker service by name (as `n8n` container → native docker service `n8n@docker`), not a file service — this matches the existing pattern (docker containers are auto-discovered by Traefik).