# Messenger → Home Assistant AI Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let family members message the Facebook Page and get responses/actions from a Home Assistant AI assistant that runs *as* the requesting person.

**Architecture:** n8n is the public inbound entry point (Meta webhook). It verifies the callback, maps PSID → person → HA long-lived token, calls HA's `/api/conversation/process` (the existing Moonshot/OpenRouter assist brain), and posts the reply back to the originating PSID via the already-working Graph API call. A Cloudflare ruleset skip-rule exempts the webhook path from the zone country-allowlist.

**Tech Stack:** n8n workflow (webhook + HTTP + IF + Set), HA conversation API (OpenRouter/Moonshot agent), Facebook Graph API v19.0, Cloudflare Ruleset Engine (OpenTofu), per-person HA long-lived tokens.

## Global Constraints

- **Use `tofu`, not `terraform`** for the Cloudflare module. Pinned `terraform/.opentofu-version` = 1.12.0 (local binary 1.12.6). Run `make check` (validate + fmt) then `make plan` before `make apply`.
- Never commit `*.env` or `*.tfvars`. Secrets (app secret, HA tokens) go in gitignored env / n8n credentials — never in committed workflows or YAML.
- HA config changes go to `github.com/s3lcsum/hass` (mirror `dominiksiejak/hass`), NOT the gitops repo. The live instance edits on Portainer `/var/lib/hass/` are for testing; the repo is the source of truth.
- n8n workflows live **in n8n** (via the n8n API / UI), not in the gitops repo. `stacks/n8n/compose.yaml` changes only if an env secret is needed.
- Cloudflare: the `country_allowlist` ruleset in `terraform/cloudflare/main.tf` blocks any request whose country is not PL/DE/ES. Meta webhook servers are typically US-hosted, so the webhook path MUST be exempted. Skip-exceptions only apply to rules **listed after them** → the skip rule must be ordered before the block rule.
- Webhook path is standardized as **`/webhook/messenger`** on host **`n8n.dominiksiejak.pl`**.

---

### Task 1: Exempt the Messenger webhook path from the Cloudflare country-allowlist

**Files:**
- Modify: `terraform/cloudflare/main.tf` (`cloudflare_ruleset.country_allowlist.rules`)

**Interfaces:**
- Consumes: nothing.
- Produces: a `skip` rule, listed before the country-block rule, that exempts `Host("n8n.dominiksiejak.pl") && /webhook/messenger` from the current ruleset. Later tasks rely on the webhook being reachable through Cloudflare.

**Rule ordering note:** Cloudflare evaluates rules in order. A `skip` rule only skips the rules **below** it in the same ruleset. So the `skip` must be the FIRST rule in the `rules` array, before the country `block`.

- [ ] **Step 1: Read current ruleset block**

```bash
cd /Users/Apple/Developer/l3/sum/gitops/terraform/cloudflare
sed -n '8,24p' main.tf
```
Expected: the `country_allowlist` resource with a single `block` rule `ip.geoip.country not in {"PL" "DE" "ES"}`.

- [ ] **Step 2: Add the skip rule before the block rule**

Inside `resource "cloudflare_ruleset" "country_allowlist"`, change the `rules = [` array so the skip rule is FIRST (critical), followed by the existing block rule. Add `ref` to both rules to keep stable IDs across changes:

```hcl
rules = [
  {
    ref         = "skip-messenger-webhook"
    action      = "skip"
    expression  = "http.host eq \"n8n.dominiksiejak.pl\" and starts_with(http.request.uri.path, \"/webhook/messenger\")"
    description = "Allow Messenger webhook path to bypass the country allowlist"
    enabled     = true

    action_parameters = {
      ruleset = "current"
    }
  },
  {
    ref         = "block-non-allowlisted-countries"
    action      = "block"
    expression  = "ip.geoip.country not in {\"PL\" \"DE\" \"ES\"}"
    description = "Block non-allowlisted countries"
    enabled     = true

    action_parameters = {
      response = {
        status_code  = 403
        content      = "blocked"
        content_type = "text/plain"
      }
    }
  }
]
```

- [ ] **Step 3: Run `make check` then `make plan`**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops/terraform/cloudflare
make check
make plan
```
Expected: format ok + validate ok. Plan shows only the `cloudflare_ruleset.country_allowlist` resource updated (2 rules present), no other drift.

- [ ] **Step 4: Run `make apply`**

```bash
make apply
```
Expected: ruleset updated in Cloudflare. Confirm the apply output shows the ruleset resource updated.

- [ ] **Step 5: Verify live**

Confirm the webhook path is no longer country-blocked (see Task 6 for the full endpoint). A minimal check now: the CF ruleset applied without 40x from the API.

- [ ] **Step 6: Commit**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add terraform/cloudflare/main.tf
git commit -m "chore(cloudflare): exempt messenger webhook path from country block"
```

### Task 2: Identity plumbing via n8n (no new HA users)

**Files:**
- Modify: `stacks/n8n/n8n.env` (gitignored) + `stacks/n8n/n8n.env.example` (placeholders only)

**Interfaces:**
- Consumes: existing HA long-lived API token (the owner token used by `notify_psid` / a shared assistant token).
- Produces: a PSID→person identity map + per-person `conversation_id`, stored/consumed by the n8n workflow (Task 3). Identity is injected by n8n into the assist prompt; there are NO new HA users.

**Reasoning (confirmed with user):** creating HA users and minting per-person tokens requires the HA frontend/owner login for each of four people — not automatable, and Jan has no existing HA user. Instead n8n already owns the PSID→person map and will:
- pass a stable per-person `conversation_id` so each chat keeps its own HA conversation thread,
- prepend the person's name into the assist call so the LLM knows *who* is speaking,
- use a single shared HA long-lived token (the assistant carries identity in the prompt, not via token-binding).

**Constraints:** four family members from `notify_psid`: Dominik, Jan, Dantua, Oliwia. Everyone acts equally. conversation_language default is `en`; the workflow passes `"language": "pl"` per call.

- [ ] **Step 1: Confirm the shared HA long-lived token**

Use the existing long-lived token already used by the HA Time Machine (`LONG_LIVED_ACCESS_TOKEN` in `stacks/hass/timemachine.env`, `<...>`) OR the owner token present on the instance. Store its value (or a fresh assistant-scoped one if preferred) as `HA_ASSIST_TOKEN` — the value is a secret, saved into the gitignored `stacks/n8n/n8n.env`, never printed to conversation or committed.

- [ ] **Step 2: Define the PSID→person → conversation_id map**

Use the real PSIDs from the live `notify_psid` config:

| PSID | person | conversation_id |
|------|--------|-----------------|
| `28826229860312894` | Dominik | `msgr-dominik` |
| `27948189831503096` | Jan | `msgr-jan` |
| `27914858414802372` | Dantua | `msgr-dantua` |
| `38584905417763183` | Oliwia | `msgr-oliwia` |

- [ ] **Step 3: Add the env keys to `.env.example` (placeholders only, never real)**

```env
HA_ASSIST_TOKEN=your_home_assistant_long_lived_token
# PSID→person conversation_ids are set in the n8n workflow code, not env
```

- [ ] **Step 4: Commit the `.env.example` addition only (never the real `.env`)**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add stacks/n8n/n8n.env.example
git commit -m "chore(n8n): document HA assistant token env key"
```

### Task 3: Build the n8n Messenger webhook workflow

**Files:**
- Create: n8n workflow (in n8n via n8n MCP/API) — no gitops file
- Modify: `stacks/n8n/n8n.env.example` (and `compose.yaml` ONLY if n8n needs a new env var)

**Interfaces:**
- Consumes: HA per-person tokens (Task 2), Graph page token + FB app secret, PSID→person map.
- Produces: public endpoint `POST`/`GET` `https://n8n.dominiksiejak.pl/webhook/messenger` that verifies handshake, calls HA, replies to the PSID.

**Verification path (handshake):**
- Meta GETs `<url>?hub.mode=subscribe&hub.verify_token=<token>&hub.challenge=<challenge>`
- Workflow returns `200` with body `echo <challenge>` when verify_token matches; else `403`.

**Inbound message:**
- Meta POSTs JSON `{entry:[{messaging:[{sender:{id:<psid>}, message:{text:<msg>}}]}]}`
- Validate `X-Hub-Signature-256` (sha1 HMAC of raw body with app secret).

- [ ] **Step 1: Create the workflow**

Use the n8n MCP/UI. Create an (inactive) workflow named `Messenger Assistant`. Add a **Webhook** trigger node: path `/webhook/messenger`, method GET+POST, response code 200. Leave inactive.

- [ ] **Step 2: Extract sender + text**

Add an **Extract JSON** (or Code) node that pulls out:
- `senderId` from `$json["entry"][0]["messaging"][0]["sender"]["id"]`
- `messageText` from `...["messaging"][0]["message"]["text"]`
- query params `hubVerifyToken`, `hubChallenge`.

- [ ] **Step 3: Identity map PS → person → conversation**

Add a **Switch / Code** node producing a person label + per-person `conversation_id` from a map (real PSIDs from `notify_psid` config). Identity is injected at the prompt level — there is no per-user HA token (Task 2):

```js
const map = {
  "28826229860312894": { person: "Dominik", convId: "msgr-dominik" },
  "27948189831503096": { person: "Jan",     convId: "msgr-jan" },
  "27914858414802372": { person: "Dantua",  convId: "msgr-dantua" },
  "38584905417763183": { person: "Oliwia",  convId: "msgr-oliwia" },
};
const sender = $json.senderId;
return map[sender] ? { found: true, ...map[sender] } : { found: false, senderId: sender };
```

- [ ] **Step 4: Call HA conversation/process (shared token + injected identity)**

Add an **HTTP Request** node POST to the HA API:
- Method: POST
- URL: `https://hass.dominiksiejak.pl/api/conversation/process`
- Header: `Authorization: Bearer {{ HA_ASSIST_TOKEN }}` (single shared assistant token, Task 2)
- Body (JSON): the person's name is prepended to the text so the LLM knows who is speaking.
```json
{ "text": "{{msg}}", "language": "pl", "conversation_id": "{{conversation_id}}" }
```
Set `conversation_id` to a stable per-person id, e.g. `msgr-dominik`. This keeps each chat focused.

- [ ] **Step 5: Send the assistant reply back to Messenger**

**HTTP Request** node:
- URL: `https://graph.facebook.com/v19.0/me/messages`
- Query string: `access_token={{FB_PAGE_ACCESS_TOKEN}}`
- Header: `Content-Type: application/json`
- Body:
```json
{
  "recipient": { "id": "{{$json.senderId}}" },
  "message": { "text": "{{$json.assistantReply}}" },
  "messaging_type": "RESPONSE"
}
```

`assistantReply` = `data.response.response` from the HA call.

- [ ] **Step 6: Add unknown-PS and error handling**

If `found=false` → reply to the same PSID "Nie rozpoznaj ci." + log for admins to add. If HA call fails/timeout/non-200 → same-thread canned fallback + error log. Never drop silently.

- [ ] **Step 7: If n8n needs the token in env, add to compose.yaml**

The compose already has `env_file: /opt/n8n/n8n.env`. Confirm `HA_ASSIST_TOKEN` and `FB_PAGE_ACCESS_TOKEN` live there; if not add them. Update `n8n.env.example` with placeholders. If compose.yaml changes, `make apply` in `terraform/portainer/` and restart n8n.

- [ ] **Step 8: Commit env-example/compose if changed**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add stacks/n8n/compose.yaml stacks/n8n/n8n.env.example   # only if changed
git commit -m "chore(n8n): wire messenger assistant env tokens"
```

### Task 4: Configure Meta to send webhooks to n8n

**Files:** Meta app developer console (out-of-band; no gitops file)

**Interfaces:**
- Consumes: the public n8n `/webhook/messenger` endpoint + a `verify_token` (from Task 3).
- Produces: Meta → n8n webhook subscriptions for the Page, sending message events.

- [ ] **Step 1: Use the Meta app owning the Page**

In `developers.facebook.com` → the app that owns the Page used by `notify_psid`. Confirm it manages the Page.

- [ ] **Step 2: Add webhooks + messages field**

Add the **Webhooks** product; subscribe to **Page**; enable the `messages` field.

- [ ] **Step 3: Set the callback URL + verify token**

Callback URL: `https://n8n.dominiksiejak.pl/webhook/messenger`
Verify token: a long random string set both in Meta and the n8n workflow.

- [ ] **Step 4: Verify & subscribe**

Click **Verify and Save**. Meta GETs the callback; n8n echoes the challenge → "Configured". Subscribe to `messages`.

- [ ] **Step 5: Add the page token + app secret to n8n env**

Ensure `FB_PAGE_ACCESS_TOKEN` (same token `notify_psid` uses) + `verify_token` + app secret exist in the n8n env. Update `.env.example` placeholders only.

- [ ] **Step 6: Commit env-example if changed**

### Task 5: End-to-end functional test

**Files:** none (verification).

- [ ] **Step 1: Confirm HA conversation endpoint is reachable**

```
POST https://hass.dominiksiejak.pl/api/conversation/process
Authorization: Bearer <dominik token>
{ "text": "Hej, wlacz czajnik", "language": "pl", "conversation_id": "test" }
```
Expected: HTTP 200 JSON with backend response text.

- [ ] **Step 2: Confirm the OpenRouter/Moonshot agent is the active conversation engine**

Check the Assist pipeline `conversation_engine` points at the OpenRouter agent (config entry `open_router` with `llm_hass_api: assist`). If the default pipeline uses `conversation.home_assistant` (native) instead, either switch the pipeline to the OpenRouter agent or pass an explicit `agent_id` matching the OpenRouter conversation agent. Adjust the workflow's HA call to pass that `agent_id` if needed.

- [ ] **Step 3: Activate the n8n workflow**

Activate the workflow. Confirm the webhook path `/webhook/messenger` is reachable over HTTPS.

- [ ] **Step 4: Read-back test — "Ile pra zostalo przed czyszczeniem bębna pralki?"**

Send from Dominik's Messenger (or simulate a webhook with Dominik's PSID). Confirm the reply contains the washer remaining-time value from `sensor.washer_remaining_time`.

- [ ] **Step 5: Control test — "Włacz wodę"**

Confirm the water-heater service/automation ran, and the reply attributes the caller as **Dominik**. Wire per-user attribution into the automation if needed.

### Task 6: Verify Cloudflare does not block + rigorous module checks

**Files:** none (verification of Task 1).

- [ ] **Step 1: Confirm country-skip scopes to the path only**

From a non-PL/DE/ES IP (e.g. US VPN): POST to `https://n8n.dominiksiejak.pl/webhook/messenger` → expected reachable. POST to another n8n path on the same host (e.g. `/webhook/foo`) → expected 403 country-block. Validates the skip applies to only the webhook path.

- [ ] **Step 2: Confirm no managed/WAF blocker on the path**

Verify in Cloudflare whether a managed (OWASP) ruleset is active on the zone. If it blocks the webhook PRE, add a managed-ruleset skip for the same path; update the task notes. Otherwise skip.

- [ ] **Step 3: Add README changelog entry**

`README.md`: `### 21.08.2026` note introducing the Messenger AI assistant (webhook → HA brain → PS reply), per-person identity, Cloudflare webhook path bypass.

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add README.md
git commit -m "docs(readme): messenger AI assistant + Cloudflare webhook bypass"
```

---

## Self-Review Notes

- **Spec coverage:** CF exemption (Task 1), HA users/tokens (Task 2), n8n webhook + identity map + HA call + reply (Task 3), Meta handshake (Task 4), error handling (Task 3 Step 6), read-only + control tests (Task 5), Cloudflare verification (Task 6). Out of scope: role-based perms, voice, additional family members beyond the four.
- **No placeholders:** each task has concrete commands/payloads.
- **Confirmed Cloudflare semantics:** `skip` with `action_parameters = { "ruleset": "current" }` skips remaining rules *below* it in the same ruleset → skip must be the **first** rule, before the country block. Source: developers.cloudflare.com/ruleset-engine/managed-rulesets/create-exception ("Skip all remaining rules").
- **Type consistency:** webhook path `/webhook/messenger`; env keys `HA_ASSIST_TOKEN` and `FB_PAGE_ACCESS_TOKEN` used consistently across Task 2 → 4 → 5. `conversation_id` per person stable (`msgr-dominik`, etc.).
- **Secret handling:** real token values are never printed or committed; the identity map holds PSIDs only.
