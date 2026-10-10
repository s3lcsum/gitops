# Toggl Work OverHours split

**Date:** 2026-10-10
**Status:** Implemented
**Extends:** [`2026-09-08-focus-toggl-calendar-design.md`](./2026-09-08-focus-toggl-calendar-design.md)

## Overview

When InPost (`project_id` `215500877`) work for the current accounting day reaches **8 hours**, stop any running timer titled `Work` and start a new timer titled **`Work OverHours`** with tag **`OH`**. Same project. Day boundary is **07:00 Europe/Warsaw**.

## Rules

| Rule | Value |
|---|---|
| Day window | `07:00` → next `07:00` Europe/Warsaw |
| Cap | 8h total on project `215500877`, any description |
| OverHours entry | description `Work OverHours`, project `215500877`, tag `OH` |
| Mid-session | cron poll: stop running `Work` → start OverHours when day total ≥ 8h |
| Already past 8h at Focus→Work | start as OverHours + `OH` immediately |
| Before 07:00 Warsaw | classic overhours: start/split as OverHours + `OH` (time belongs to previous window) |
| Poll interval | 5 minutes |
| Trigger style | cron (not Wait-after-respond) |

## Day-total algorithm

```
windowStart = today 07:00 Warsaw (if now >= 07:00) else yesterday 07:00
windowEnd   = windowStart + 24h
for each InPost entry overlapping [windowStart, windowEnd):
  add clamped duration (stop or now for running)
threshold = 8 * 3600
```

- Running entry counted once.
- After split, OverHours continues to count toward the same 8h (already past → no re-split).
- Time before 07:00 does not count toward the new day’s 8h.

## Workflows

### A. `focus-webhook` (modify)

Repo: `kubernetes/n8n/workflows/focus-webhook.json` (id `60spqj9OfT64ZL1q`).

On Focus `Work` start path:

1. Compute day window bounds (Warsaw).
2. `GET /api/v9/me/time_entries?start_date=&end_date=`.
3. Sum InPost durations clamped to the window (include running elapsed).
4. If `now < 07:00` **or** `sum >= 8h` → description `Work OverHours`, `tag_ids: [OH_TAG_ID]`; else `Work`, no OH tag.
5. **Resume (5 min):** only when remembered `last_timer_project_id` matches **and** remembered `last_timer_description` matches the chosen target description. Prevents gluing OverHours back into a single `Work` entry across a split.

Fitness path unchanged. Start POST body includes `tag_ids` when OverHours.

### B. `toggl-overhours-schedule` (new)

Repo: `kubernetes/n8n/workflows/toggl-overhours-schedule.json` (id `nwHBjRYInriH2HAk`, active).

- Schedule every **5 minutes**, `misfirePolicy: skip`.
- GET current → if not InPost or description ≠ `Work` → exit.
- Sum day window (same algorithm) + running elapsed.
- If before 07:00 **or** total ≥ 8h → stop current → POST running `Work OverHours` + `tag_ids: [OH]`, `created_with: n8n-toggl-overhours`.
- Idempotent: never split if already OverHours / already tagged OH.
- No SSH / Focus changes. Do **not** revive `work-reconcile-schedule`.

### C. Toggl tag `OH`

Workspace tag **`OH`** id **`21007204`** (created 2026-10-10). Workflows resolve by exact name `OH` and create if missing; do not use the older emoji tag `OH 🕐` (`20966341`).

## Out of scope

- Wait-after-respond precise cut
- Separate OverHours Toggl project
- Calendar sync title changes (shows `InPost — Work OverHours` naturally)
- Re-enabling Focus↔Toggl reconcile

## Verification

1. Day with &lt;8h Work → Focus Work starts `Work`, no OH.
2. Seed ≥8h InPost in window → Focus Work starts `Work OverHours` + OH.
3. Running `Work` past 8h → within one poll cycle: stop + OverHours+OH.
4. Before 07:00 → start/split as OverHours.
5. Stop during Work, Focus Work again &lt;5 min → resume same desc/start.
6. After OH split, stop, Focus Work &lt;5 min with day still ≥8h → resume/start OverHours (not merge into Work).
7. Fitness unaffected.
