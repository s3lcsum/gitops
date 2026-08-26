# Apple Focus → n8n → Toggl Timer

**Date:** 2026-08-26
**Status:** Approved design
**Author:** opencode

## Overview

Four iOS Focus modes (`DND`, `Work`, `Fitness`, `Personal`) fire Shortcuts automations on activation. Each automation POSTs the new focus name to a secret-protected n8n webhook. The workflow:

1. Logs every transition (timestamp + focus) to an **n8n Data Table** (`focus_history`).
2. Keeps a single **Toggl Track** timer in sync: entering `Work`/`Fitness` ensures the matching timer runs (stopping any other), entering `DND`/`Personal` stops whatever is running.

Single-workflow architecture (Approach A): one webhook workflow does logging + timer control, matching the existing `stacks/n8n/workflows/*.json` convention.

## Components

### 1. Apple Shortcuts (iPhone)

One automation per focus: **When \<Focus\> turns on → Run Immediately** (Ask Before Running off) → shortcut "Focus Changed":

- Text parameter = focus name exactly as spelled above.
- **Get Contents of URL**: `POST https://n8n.dominiksiejak.pl/webhook/focus-change`
  - Headers: `x-webhook-secret: <FOCUS_WEBHOOK_SECRET>`, `Content-Type: application/json`
  - JSON body: `{"focus": "<Focus Name>"}`

Optional (recommended): duplicate automations on **turn off** sending `{"focus": "<Name>", "state": "off"}` so disabling a focus without enabling another still stops the timer.

### 2. Traefik

No changes. `/webhook*` already routes to n8n **without** Authentik forward-auth.

### 3. Secret

- `FOCUS_WEBHOOK_SECRET` = `openssl rand -hex 32`
- Live value → `/opt/n8n/n8n.env`; placeholder → `stacks/n8n/n8n.env.example`.
- Read in-workflow via `$env.FOCUS_WEBHOOK_SECRET` (same pattern as `AUTHENTIK_WEBHOOK_SECRET`; `$env` works in standard nodes, Code nodes stay untouched).

### 4. n8n Workflow `focus-toggl`

```
Webhook (POST /webhook/focus-change)
  → Validate Secret (IF: headers['x-webhook-secret'] === $env.FOCUS_WEBHOOK_SECRET)
      false → Respond 401 {"error":"unauthorized"}
      true  → Normalize (Set: focus = trim/lowercase(body.focus),
                        state = body.state ?? "on",
                        changed_at = $now ISO-UTC)
             → Data Table: insert row into focus_history
             → Respond 200 {"logged": true}          // phone acked; rest is async
             → IF (state === "off")                  // any focus turning off
                   true  → Stop-if-running branch
                   false → Switch (focus):
                             [work, fitness] → Tracked-focus branch
                             [dnd, personal] → Stop-if-running branch
                             fallback        → End (already logged)
```

#### Tracked-focus branch (Work | Fitness)

1. `GET https://api.track.toggl.com/api/v9/time_entries/current` (HTTP Request, auth = Predefined Credential Type → existing `togglApi` credential).
2. Decision:
   - No current entry → **start** new timer.
   - Current entry description == `DESC[focus]` → **do nothing** (keeps one continuous session).
   - Current entry description != `DESC[focus]` (incl. manually started timers) → **stop**, then **start**.
3. Start = `POST /api/v9/workspaces/{TOGGL_WORKSPACE_ID}/time_entries` with `{description: DESC[focus], workspace_id, created_with: "n8n-focus-toggl"}` (n8n sets negative duration/start).

#### Stop-if-running branch (DND | Personal | any `state: "off"` event)

1. `GET .../time_entries/current`
2. Entry exists → `POST .../workspaces/{wid}/time_entries/{entry.id}/stop`. None → done.

#### Config (env-driven, editable without touching workflow)

| Env var | Default | Purpose |
|---|---|---|
| `FOCUS_WEBHOOK_SECRET` | required | request auth |
| `TOGGL_WORKSPACE_ID` | required | Toggl workspace |
| `TOGGL_DESC_WORK` | `"Work inPost"` | Work timer description |
| `TOGGL_DESC_FITNESS` | `"Fitness"` | Fitness timer description |

Guard: if `TOGGL_WORKSPACE_ID` unset, skip all Toggl calls (logging still works).

### 5. Data Table `focus_history`

Created once in n8n UI (Data Tables feature; stored inside n8n's own postgres volume):

| Column | Type |
|---|---|
| `id` | auto |
| `focus` | string |
| `state` | string (`on`/`off`) |
| `changed_at` | date |

### 6. Deployment

1. Create Data Table + set env vars → restart `n8n` container.
2. Import `stacks/n8n/workflows/focus-toggl.json` (UI → Import from File), wire the `togglApi` credential on the three HTTP Request nodes, activate.
3. Commit workflow JSON to repo per convention.
4. MCP path currently broken (`AUTHENTICATION_ERROR` — likely `N8N_API_ENABLED=false`/stale key in `.mcp.json`). Manual import unless fixed; fixing MCP is out of scope but noted as follow-up.

## Error handling

- Bad/missing secret → 401, nothing logged.
- Unknown focus string → logged, no timer action, 200.
- Toggl call failures surface in n8n Executions; phone already got its 200 (ack precedes Toggl logic).
- Duplicate/out-of-order Shortcut deliveries are naturally idempotent: re-sending the same focus hits the "description matches → do nothing" path.

## Known limitations

- Focus **turn-off without a replacement focus** keeps timers running unless the optional `state: "off"` automations are installed.
- Phone clock is never trusted; timestamps are server-side (`$now`).
- Only one running Toggl timer is modeled (Toggl itself enforces at most one).

## Testing plan

1. `curl -X POST .../webhook/focus-change` without secret → 401; with secret + `{"focus":"Work"}` → row appears in `focus_history`.
2. With `TOGGL_WORKSPACE_ID` unset → no Toggl calls, log rows still written.
3. E2E: start Work → verify Toggl timer "Work inPost"; switch to Fitness → old stopped, "Fitness" started; switch to Personal → stopped.
