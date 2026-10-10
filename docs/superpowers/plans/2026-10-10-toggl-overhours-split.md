# Toggl OverHours Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split InPost Toggl `Work` into `Work OverHours` + tag `OH` at 8h (day window 07:00 Europe/Warsaw), via focus-webhook start path and a 5-minute cron workflow.

**Architecture:** `focus-webhook` fetches day entries on Focus→Work ON and chooses description/tags before start/resume. New `toggl-overhours-schedule` polls every 5 minutes and splits a running `Work` entry when the day total crosses 8h (or before 07:00).

**Tech Stack:** n8n workflows (JSON exports), Toggl Track API v9, Europe/Warsaw day math in Code nodes.

## Global Constraints

- Workspace `3825058`, InPost project `215500877`, tag name `OH` (numeric id pinned after lookup/create).
- Day window 07:00→07:00 Europe/Warsaw; threshold `8 * 3600` seconds.
- OverHours description exact: `Work OverHours`; `created_with` cron: `n8n-toggl-overhours`.
- Resume requires same project **and** same description within 5 minutes.
- Do not revive `work-reconcile-schedule`. No SSH in overhours cron.
- Repo path: `kubernetes/n8n/workflows/`. Spec: `docs/superpowers/specs/2026-10-10-toggl-overhours-split-design.md`.

---

### Task 1: Pin OH tag id

**Files:**
- Modify: workflow Code/HTTP bodies that reference `OH_TAG_ID`

- [x] **Step 1:** List workspace tags via Toggl API (`GET /workspaces/3825058/tags`). Create `OH` if missing (`POST`).
- [x] **Step 2:** Record numeric id `21007204`; workflows resolve by name `OH` (create-if-missing).

### Task 2: Update `focus-webhook` ON path

**Files:**
- Modify: `kubernetes/n8n/workflows/focus-webhook.json`

- [x] **Step 1:** After `Get Current Timer (Focus On)`, add `Prepare OverHours Context` (stash current + window ISO dates) and `Fetch Day Entries` (GET time_entries for window).
- [x] **Step 2:** Rewrite `Plan Immediate On` to sum InPost clamped durations; if Work and (before 07:00 or sum≥8h) set description `Work OverHours` + `tag_ids`; else keep target description; match/resume on project+description; emit `tag_ids`.
- [x] **Step 3:** Update `Start Focus Timer` JSON body to include `tag_ids` when non-empty.
- [x] **Step 4:** Wire connections: Get Current → Prepare → Fetch Day Entries → tags → Plan Immediate On.

### Task 3: New `toggl-overhours-schedule`

**Files:**
- Create: `kubernetes/n8n/workflows/toggl-overhours-schedule.json`

- [x] **Step 1:** Schedule 5 min → Get Current → if InPost + desc `Work` → Fetch Day Entries → Decide Split → Stop → Start OverHours+OH.
- [x] **Step 2:** Idempotent skip if not split candidate / already OverHours.
- [x] **Step 3:** Export active-ready JSON with `togglApi` credential `LT5dvmGwtJLuyDp7` (id `nwHBjRYInriH2HAk`).

### Task 4: Docs + activate

**Files:**
- Modify: `docs/superpowers/specs/2026-10-10-toggl-overhours-split-design.md` (status + tag id)
- Modify: `docs/superpowers/specs/2026-09-08-focus-toggl-calendar-design.md` (workflow table — done if already updated)

- [x] **Step 1:** Set spec Status to Implemented; pin `OH` tag id `21007204`.
- [x] **Step 2:** Import/update workflows via n8n CLI; publish + restart n8n; both active.
- [x] **Step 3:** Day-window unit smoke + live export check (full E2E overtime split needs a ≥8h Work day).
