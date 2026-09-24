# Focus ↔ Toggl InPost ↔ Google Calendar (Toggl)

**Date:** 2026-09-08
**Status:** Implemented (with noted blockers)
**Supersedes:** `docs/superpowers/specs/2026-08-26-focus-toggl-webhook-design.md`

## Overview

n8n at `https://n8n.dominiksiejak.pl` orchestrates Apple Focus → matching Toggl timer (plus Data Table state from Toggl webhooks; **no** automatic Toggl→Focus), plus an authoritative Toggl → Google Calendar sync onto a dedicated calendar named **`Toggl`**.

## Workflows

The combined `work-state-controller` was split into three active workflows (shared Data Table singleton). The old combined workflow is **inactive** and renamed `zz-archived-work-state-controller` (`2x4mVjHEzlwPkvCI`) — do not re-enable it.

| Workflow | ID | Trigger |
|---|---|---|
| `focus-webhook` | `60spqj9OfT64ZL1q` | Focus `POST /webhook/focus-work` |
| `toggl-webhook` | `hOi5vpTB7uAvSH72` | Toggl `POST /webhook/toggl-time-entry` (state only; no Focus SSH) |
| `work-reconcile-schedule` | `sa0Ufb9jP9QQO0Pf` | **inactive** (was Toggl→Focus drift repair; deactivated 2026-09-09) |
| `toggl-calendar-sync` | `4dVHTshAnUXeUQvv` | Force sync `POST /webhook/toggl-calendar-sync`, hourly schedule |
| `zz-archived-work-state-controller` | `2x4mVjHEzlwPkvCI` | **inactive** (archived combined controller) |

Repo exports: `stacks/n8n/workflows/focus-webhook.json`, `toggl-webhook.json`, `work-reconcile-schedule.json`, `toggl-calendar-sync.json`.

## State & secrets

### Data Tables

- `work_state_controller` (`RQF9wB5DfMaXfV6R`) — singleton controller row (`singleton_key=controller`)
- `toggl_calendar_map` (`MTg7lr2c9RQTgKiz`) — entry↔event mappings
- `toggl_calendar_meta` (`yCdUzlNRSpJESMzO`) — calendar id + sync markers
- `integration_secrets` (`dpZoIRhIm8gMd8KU`) — `TOGGL_WEBHOOK_SECRET` (Toggl subscription `secret` + HMAC verify per [Validating Received Events](https://engineering.toggl.com/docs/track/webhooks_start/validating_received_events/)); Focus uses n8n Header Auth credential instead of `$env` because `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` blocks `$env` in Set/Code on n8n 2.38

### Credentials

- Toggl account `LT5dvmGwtJLuyDp7`
- Google Calendar account `LorPyV1FeJrqDuIa` (**needs OAuth reconnect** for hourly n8n sync)
- `focus-webhook-secret` Header Auth `WcOswv3jQQPbP1Uh` (`x-webhook-secret`)
- `vibe Focus SSH` `Yy9vPF9jQvlHsVtX` → `Apple@192.168.89.200`

### Env (on `/opt/n8n/n8n.env`, examples in `stacks/n8n/n8n.env.example`)

- `FOCUS_WEBHOOK_SECRET`
- `TOGGL_WEBHOOK_SECRET` (also mirrored into Data Table; Toggl subscription `secret` for `X-Webhook-Signature-256` HMAC)
- `TOGGL_WORKSPACE_ID=3825058`
- `TOGGL_INPOST_PROJECT_ID=215500877`
- `TOGGL_CALENDAR_ID=8c8fc35e0478c9bf6e2a7f86f29b90448a0f81ff59854727d20efbfa7a93cdb7@group.calendar.google.com`
- Compose: SSRF allowlist includes `192.168.89.200/32`

## Behaviour

### Focus → Toggl (immediate ON and OFF)

1. Personal Automation POSTs JSON with **only** `{ "focus": "<name>" }` and header `x-webhook-secret`. No `state` field.
2. **Timer map** (exact Focus name after trim → Toggl project + description). Only **Work** and **Fitness** are tracked:

| Focus | Toggl project | project_id | description |
|---|---|---|---|
| `Work` | InPost | `215500877` | `Work` |
| `Fitness` | Fitness | `222326897` | `Fitness` |
| `Sleep` / `Personal` / `Do not disturb` / `""` / unknown | — | — | **stop** any running timer |

3. Switching Focus (e.g. Work → Fitness) is a single POST of the new name: stop the previous timer if different project, then start the mapped one (idempotent if already correct).
4. **5-minute same-project resume:** stop is always immediate. On stop, controller stores `last_timer_entry_id` / `last_timer_start` / `last_timer_project_id` / `last_timer_stopped_at`. If the same project is started again within **5 minutes**, DELETE the stopped entry and POST a new running entry with the **original start** (one continuous Toggl entry). Different project → no resume; previous stopped entry is kept.
5. **ON (Work / Fitness):** after auth — resume or start mapped timer; SSH `Set Work Focus` only for `Work` when `work_active` mismatches. `work_active` is true only while Focus is `Work`.
6. **OFF (Sleep / Personal / DND / empty / unknown):** stop any running timer and remember it for the resume window; SSH `Clear Work Focus` only when clearing Work state (`need_focus`).
7. `suppress_own_focus` applies only to `Work` POSTs (SSH echo guard). Leftover `focus_pending_*` fields are cleared on apply; unused for routing.

### Toggl → state only (no automatic Focus)

**Changed 2026-09-09:** Toggl timers no longer drive Apple Focus. Direction is one-way Focus → Toggl.

1. Toggl time_entry webhooks authenticated via official HMAC ([Validating Received Events](https://engineering.toggl.com/docs/track/webhooks_start/validating_received_events/)): webhook `rawBody: true`, secret from Data Table `TOGGL_WEBHOOK_SECRET`, HMAC-SHA256 over **full unparsed raw body bytes**, header `X-Webhook-Signature-256` form `sha256={hex}`, `timingSafeEqual` compare. Invalid → `401 {"error":"invalid_signature"}`. Valid ping/`validation_code` → `200` echo `validation_code`. No query-secret auth and no ping-bypass-without-auth. Callback URL is bare `https://n8n.dominiksiejak.pl/webhook/toggl-time-entry`; subscription create sets `"secret":"<TOGGL_WEBHOOK_SECRET>"`. Requires `NODE_FUNCTION_ALLOW_BUILTIN=crypto` on the n8n container.
2. On relevant InPost start/stop/delete → update Data Table `work_active` (+ ack webhook). **No SSH Focus shortcuts.**
3. `work-reconcile-schedule` (5-minute Toggl poll + SSH Focus repair) is **deactivated** — Focus→Toggl is handled immediately by `focus-webhook`; Toggl→Focus drift repair is intentionally gone.

### Calendar

- Google calendar **`Toggl`** (Europe/Warsaw).
- Titles: `Project — Description`.
- Description includes a Toggl Calendar link for that entry's Warsaw day (`https://track.toggl.com/<workspace>/calendar/<year>/<month>/<day>`), then the private marker `[toggl:<id>]`. `extendedProperties.private.toggl_entry_id` is set when the API allows.
- Hourly sync no longer waits on a 2-input merge after create/update and delete. A run that only creates events used to sit on `Finish Merge` forever, and `misfirePolicy: skip` then dropped every later hour (last write 2026-09-15 21:00 UTC). Both branches now go straight to `Mark Sync Done`, empty source branches still emit one item, and a missed hour fires instead of being skipped.
- **Toggl is authoritative:** create/update/delete on hourly sync (`toggl-calendar-sync`). Deleting a time entry in Toggl queues `op:delete` on the next sync — removes the mapped Google event (via Calendar API DELETE) and drops the row from `toggl_calendar_map`. Detection uses both live calendar events and persisted mappings (so deletes still work when GCal list misses an event).
- Initial 30-day backfill: **17 entries** loaded 2026-09-08.
- Force sync: `POST https://n8n.dominiksiejak.pl/webhook/toggl-calendar-sync`

## Verification (2026-09-08; …; Work+Fitness only 2026-09-14; 5-min resume 2026-09-15)

| Check | Result |
|---|---|
| `focus-webhook` validate | pass (Work+Fitness + 5-min resume) |
| `toggl-webhook` validate (SSH Focus nodes removed) | pass |
| `work-reconcile-schedule` | **inactive** |
| `toggl-calendar-sync` validate | pass (unchanged) |
| Archived `zz-archived-work-state-controller` | inactive (not re-enabled) |
| Focus `{"focus":"Fitness"}` → start Fitness | pass |
| Focus leave Fitness then Fitness again within 5 min | pass (`need_resume:true`, same `start_iso`) |
| Focus `{"focus":"Work"}` → Toggl InPost | pass |
| Focus Work → Fitness → Work within 5 min | pass (resume Work original start) |
| Focus Work → Fitness | pass (`need_resume:false` for Fitness; Work remembered) |
| Focus `{"focus":"Sleep"}` / Personal / `""` | `applied:off` (stop + remember) |
| Focus `{"focus":"Do not disturb"}` | `applied:off` (stop-if-running) |
| Focus bad `x-webhook-secret` | `403 Authorization data is wrong!` |
| Toggl missing/bad `X-Webhook-Signature-256` | `401 {"error":"invalid_signature"}` |
| Toggl ping with valid HMAC + `validation_code` | `200 {"validation_code":"manual-test"}` (openssl smoke 2026-09-09) |
| Force calendar sync webhook | Google OAuth may need reconnect if 500 |
| Initial 30-day calendar backfill | 17 events created on calendar **Toggl** (via Composio) |
| `ssh vibe 'shortcuts list'` | empty — Apple Shortcuts not created yet |
| Toggl free-plan API quota | can throttle rapid E2E; wait for hourly reset |
| Portainer `n8n` stack | applied (`2.38.4`, SSRF + `NODE_FUNCTION_ALLOW_BUILTIN=crypto` for Toggl HMAC) |

## Apple Shortcuts (manual — one-time)

**BLOCKER:** these do not exist on vibe yet (`shortcuts list` is empty). Create them before Focus↔InPost E2E can complete.

### A. Focus-reporting automations (iPhone and/or Mac you use for Focus)

Shortcuts must POST **only** the current Focus name (or `""` when Focus is off). There is **no** `state` field.

Shared request shape for every automation:

- Method `POST`
- URL `https://n8n.dominiksiejak.pl/webhook/focus-work`
- Headers: `x-webhook-secret: <FOCUS_WEBHOOK_SECRET from /opt/n8n/n8n.env>`, `Content-Type: application/json`
- Body JSON examples (one key only):

```json
{"focus":"Work"}
{"focus":"Fitness"}
{"focus":"Sleep"}
{"focus":"Personal"}
{"focus":"Do not disturb"}
{"focus":""}
```

**Recommended setup:** one Personal Automation per Focus mode you care about (and optionally “when Focus turns off”), each posting the matching body above. Ask Before Running: **Off**.

Examples:

1. When **Work** / **Fitness** turns **On** → body with that Focus name (starts InPost or Fitness timer).
2. When **Sleep** / **Personal** / **Do Not Disturb** turns on → body with that Focus name (stops any running timer; no new timer).
3. When Focus turns **off** (no Focus active) → body `{"focus":""}` (stops any running timer).

Work→Fitness is a single POST of `{"focus":"Fitness"}`; do not send a separate Work-off event.

### B. vibe Focus-setting shortcuts (always-on Mac `vibe` / `Apple@192.168.89.200`)

**Shortcut `Set Work Focus`**

1. New Shortcut named exactly `Set Work Focus`.
2. Action: **Set Focus** → Focus = **Work** → Turn **On** Until **Turned Off**.
3. Ensure Focus → Share Across Devices is enabled on vibe and your phone.

**Shortcut `Clear Work Focus`**

1. New Shortcut named exactly `Clear Work Focus`.
2. Action: **Set Focus** → Focus = **Work** → Turn **Off**.

Smoke: `ssh vibe 'shortcuts run "Set Work Focus"'` then `shortcuts run "Clear Work Focus"`.

## Cloudflare WAF note

Country allowlist must skip `/webhook/toggl-time-entry` (and preferably `/webhook/focus-work`). Terraform change is in `terraform/cloudflare/main.tf`; apply is blocked until a valid Cloudflare API token is available (`defaults.auto.tfvars` token currently invalid). Until then Toggl cannot register the webhook (URL probe returns 403 from non-PL/DE/ES).

## Toggl webhook registration (after WAF)

```bash
# Free plan: 1 webhook / workspace.
# Bare url_callback + subscription "secret" (HMAC). Do not put ?secret= on the URL.
# Secret = Data Table TOGGL_WEBHOOK_SECRET (mirrored in n8n.env). Do not commit the real value.
# Validation: https://engineering.toggl.com/docs/track/webhooks_start/validating_received_events/
curl -u "$TOGGL_API_TOKEN:api_token" -X POST \
  -H 'Content-Type: application/json' -H 'User-Agent: n8n-toggl-webhook' \
  -d '{
    "url_callback":"https://n8n.dominiksiejak.pl/webhook/toggl-time-entry",
    "secret":"<TOGGL_WEBHOOK_SECRET>",
    "enabled":true,
    "description":"n8n toggl-webhook time_entry",
    "event_filters":[
      {"entity":"time_entry","action":"created"},
      {"entity":"time_entry","action":"updated"},
      {"entity":"time_entry","action":"deleted"}
    ]
  }' \
  https://api.track.toggl.com/webhooks/api/v1/subscriptions/3825058
```
