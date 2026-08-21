# Design: Messenger → Home Assistant AI Assistant

Date: 2026-08-21
Status: Approved (brainstorm complete)

## Problem / Goal

Family members (Polish-only, non-technical) send messages to the Facebook Page. We
want a virtual assistant in-home that:

- Interprets natural Polish chat messages from authenticated family members.
- Acts on Home Assistant **as the requesting person** (e.g. "Włacz wodę" triggers the
  water-heater automation; the automation knows *who* asked).
- Reads HA state and answers questions (e.g. "Ile prań zostalo przed czyszczeniem bębna
  pralki?" → returns washer remaining-time).
- Replies in the same Messenger thread.

This builds **on** the already-deployed `notify_psid` outbound platform (sends HA →
Messenger) but adds the **inbound** direction (Messenger → HA brain) which does not
exist today.

## Architecture

```
[Family Messenger chat] --Meta webhook POST--> [n8n (public) /webhook/messenger]
                                                     │  n8n: verify sig, map PSID→person→token
                                                     ▼
                                               [HA /api/conversation/process]
                                                     │  assist brain (OpenRouter/Moonshot)
                                                     ▼  reads state / calls services
                                               [reply text]
                                                     │
                                                     ▼
                                               [Graph API me/messages → same PSID]
```

Three components:

| Component | Role | Status |
|-----------|------|--------|
| **n8n workflow** | Public inbound entry point (Meta webhook target) + orchestrator: signature verify, PSID→person→token map, call HA, send reply | **new** |
| **HA conversation agent** | The "brain": interprets Polish, reads entities, calls services. Already running via `open_router` config entry (Moonshot Kimi, `llm_hass_api: assist`) | **already live** |
| **Per-person HA users + tokens** | Identity so Assist runs *as* the person who asked | **new** |

Public entry point: **n8n.dominiksiejak.pl** (now internet-reachable by user action).
This avoids poking a hole through to HA directly. n8n calls HA with a per-person Bearer
token; HA is never publicly routable to the internet.

## 2. Home Assistant setup (new)

- Create HA users: **Dominik**, **Jan**, **Dantua**, **Oliwia**, one per family member.
- Issue a long-lived token for each. Store in n8n credential/secret mapping, not in
  workflows.
- Ha-Moonshot `open_router` agent already has `llm_hass_api: assist`, so the agent can
  read state + invoke service calls.
- The current pipeline `conversation_language: en` — we set `language: "pl"` per request.

## 3. n8n workflow logic

1. **Webhook trigger** — `/webhook/messenger` (public), GET+POST.
2. **Verify callback** — Meta handshake: GET with `hub.mode=subscribe`,
   `hub.verify_token`, `hub.challenge`. Return challenge if token matches; else 403.
3. **On message** — validate `X-Hub-Signature-256` vs app secret (sha1 HMAC of payload).
   Parse `entry[0].messaging[0]`: `sender.id` (PSID) + `message.text`.
4. **Identity map** — PSID → person → HA token. All family PSIDs already known in the
   notify config (`notify_psid` entities).
5. **Call HA** — `POST /api/conversation/process`
   Body: `{"text": <msg>, "language": "pl", "conversation_id": <per-person stable id>}`
   Header: `Authorization: Bearer <that person's token>`, `Content-Type: application/json`.
6. **Reply** — read `data.response.response` (assistant text). POST to
   `graph.facebook.com/v19.0/me/messages` → `recipient.id=<originating PSID>`, using
   `messaging_type: RESPONSE`. Same call as the existing `notify_psid` platform.

Identity/threading: a stable **`conversation_id` per person** keeps each chat in its
own HA conversation so follow-ups carry context, and the LLM knows who is speaking.

## 4. Home Assistant security & identity details

- Each user's long-lived token is used only inside n8n; never exposed.
- Because Assist runs authenticated as that user, HA applies entity permissions and
  the `user` is available to the LLM for attribution.
- All family members act **equally** (no roles) — decided.

## 5. Cloudflare WAF exemption (required for the webhook)

Constraint found in `terraform/cloudflare/main.tf`: a **zone-wide** custom WAF ruleset
(`country_allowlist`) `block`s any request whose geographic country is not PL/DE/ES.
Meta's webhook delivery servers do not reliably resolve to those countries, so the
callback would be 403'd in Cloudflare edge before reaching n8n.

**Required change** — exempt the webhook path from the country block:

- In the same `cloudflare_ruleset` `country_allowlist`, add a **`skip` rule with a
  higher precedence (lower number) than the country block**, matching *only*:
  - host == `n8n.dominiksiejak.pl`
  - AND path prefix `/webhook/messenger` (e.g. `starts_with(http.request.uri.path, "/webhook/messenger")`)
  - Example rule: action `skip`, expression `http.host eq \"n8n.dominiksiejak.pl\" and starts_with(http.request.uri.path, \"/webhook/messenger\")`, `action_parameters.ruleset = "current"`.
  `skip` will short-circuit the country-block for exactly this path. All other requests
  keep the country restriction.
- This is path-specific (not host-wide), so the rest of n8n, dormant apps, auth, etc.
  remain country-allowlisted.
- **Managed ruleset check:** a Cloudflare managed (OWASP) ruleset may also be active on
  the zone. If after deploy a live webhook test still 403s, add a Cloudflare managed
  rule skip dedicated for the same `/webhook/messenger` path. Verify with a live call.

## Error handling (n8n reply)

| Case | Behavior |
|------|----------|
| Handshake `verify_token` mismatch | Return 403; no HA call |
| Unknown PSID | Reply "Nie k /recognized" in chat, log for admins to add |
| HA call timeout / error / non-200 | Reply fallback, log error |
| LLM empty / refusal reply | Reply canned "Nie wam / ..." |

Never silently drop an inbound request — the family member always gets a response.

## 6. Testing (verification)

1. Meta callback handshake → "Configured" in the Meta app.
2. From Dominik's Messenger: "Ile pra skuło..." → confirm numeric answer with remaining
   time.
3. From Dominik's Messenger: "Włacz temperaturę" → confirm water-heater automation ran,
   and attribution says Dominik.
4. Jan sends a follow-up → confirm conversation continuity in his thread.
5. Repeat read + control command from a 2nd family member (e.g. Dantua).
6. **Cloudflare**: confirm the live webhook POST from Meta is *not* country-blocked,
   while an ordinary request to another n8n path on the same host from a non-allowlisted
   country/network is still 403.

## Files touched

- `terraform/cloudflare/main.tf` — add high-priority skip rule to `country_allowlist`
  for the `/webhook/messenger` path.
- HA (live instance / `github.com/s3lcsum/hass`): users + long-lived tokens; verify
  Assist pipeline + conversation agent config.
- n8n: new webhook workflow, not a compose change (workflow lives in n8n).
- `stacks/n8n/compose.yaml`: only if n8n needs an env secret (app secret / tokens) — keep
  minimal.

## Deferred / out of scope

- Role-based per-user permissions (explicitly non-goal — "everyone acts equally").
- Voice (Local Ask) interface — separate effort.
- Additional family PSIDs beyond the four known.
