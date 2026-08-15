# Grafana Read-Only Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Grafana read-only for all human users by forcing the Authentik `role` claim for the grafana app to always emit `Viewer`, so every config change arrives only via CasC (`stacks/` compose/provisioning + `terraform/`).

**Architecture:** Single declarative change in `terraform/authentik/locals.tf` — replace the grafana app's group-branching scope mapping with a static `return {"role": "Viewer"}`. Grafana already reads the `role` claim at OIDC login (`GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH=role`), so every login self-heals the user's org role to Viewer. The local `admin` account (from `grafana.env`) is untouched and remains the automation/provisioning identity. Apply via OpenTofu in TFC workspace `gitops-authentik`.

**Tech Stack:** OpenTofu (`tofu`), `authentik_provider_oauth2` scope mapping (Python expression), TFC workspace `gitops-authentik`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-15-grafana-readonly-design.md`.
- **Terraform binary is `tofu`** (never `terraform`). Run from `terraform/authentik`.
- TFC workspace is `gitops-authentik`; auth token lives in `defaults.auto.tfvars` (gitignored, sensitive).
- `terraform/authentik/locals.tf` already has **uncommitted changes** (the `hermes`/`calibre-gui` app blocks from prior work) — do not touch, revert, or amend them; only the `grafana` mapping block changes in this plan.
- Authentik scope mappings use Python-like expression syntax — keep `return {"role": "Viewer"}` exactly.
- Do **not** modify `stacks/monitoring/grafana.env`, `stacks/monitoring/compose.yaml`, or any `GF_AUTH_*`/`GF_USERS_*` setting — Grafana side stays as-is.
- Commit format per repo: conventional, e.g. `fix(authentik): force grafana role claim to Viewer`. Commits may use `--no-verify`.

---

### Task 1: Force the grafana `role` claim to always emit Viewer

**Files:**
- Modify: `terraform/authentik/locals.tf:106-121` (the `grafana = { ... }` block inside `oauth2_applications`, `mapping` heredoc)
- Test: live verification via `tofu apply` + Authentik/Grafana (no unit tests exist in this repo for `.tf`)

**Interfaces:**
- Consumes: existing `oauth2_applications` map in `locals.tf`, applied through `authentik_provider_oauth2` resources (in `applications.tf`/resources) in the same plan.
- Produces: updated `role` claim mapping so `dreewniak@gmail.com` and any future OIDC user log into Grafana with org role `Viewer`.

- [ ] **Step 1: Edit the grafana scope mapping to emit Viewer unconditionally**

In `terraform/authentik/locals.tf`, replace the grafana block's `mapping` heredoc. Current content (lines ~106-121):

```hcl
    grafana = {
      name          = "Grafana"
      launch_url    = "https://grafana.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/grafana.svg"
      redirect_uris = ["https://grafana.dominiksiejak.pl/login/generic_oauth"]
      mapping       = <<-EOF
        if request.user.ak_groups.filter(name="admins").exists():
            return {"role": "Admin"}
        elif request.user.ak_groups.filter(name="users").exists():
            return {"role": "Editor"}
        return {"role": "Viewer"}
      EOF
    }
```

New content (only the `mapping` heredoc body changes; the four keys above stay identical, and the lines below the block — the `}` closing `oauth2_applications` and the section comment — stay identical):

```hcl
    grafana = {
      name          = "Grafana"
      launch_url    = "https://grafana.dominiksiejak.pl"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/svg/grafana.svg"
      redirect_uris = ["https://grafana.dominiksiejak.pl/login/generic_oauth"]
      mapping       = <<-EOF
        return {"role": "Viewer"}
      EOF
    }
```

- [ ] **Step 2: Format and validate**

Run, in `terraform/authentik`:

```bash
tofu validate
```

Expected: `Success! The configuration is valid.`

Also run (repo pattern for pre-apply hygiene):

```bash
tofu fmt   # should report nothing to change aside from pre-existing uncommitted blocks
```

If `fmt` rewrites unrelated lines (because of the pre-existing uncommitted `hermes`/`calibre-gui` blocks differ from a previously formatted state), only apply diffs to the `grafana` mapping — do not reformat the whole file.

- [ ] **Step 3: Plan and confirm only the mapping change**

Run, in `terraform/authentik`:

```bash
tofu plan
```

Expected: exactly **one** resource update — `authentik_property_mapping_provider_scope.custom_claims["grafana"]` will be updated **in-place** (its `expression` heredoc loses the group branches and becomes `return {"role": "Viewer"}`). The plan diff must show `"role": "Admin"`/`"role": "Editor"` branch removed and only `return {"role": "Viewer"}` remaining. **No creates, no destroys.** The mapping resource is created by `authentik_property_mapping_provider_scope.custom_claims` (`applications.tf:7-17`), named `grafana-custom-claims`, reused in-place via the `property_mappings` concat (`applications.tf:43-46`). If unrelated resources appear (e.g. from the pre-existing uncommitted `hermes`/`calibre-gui` blocks), stop and investigate before applying.

- [ ] **Step 4: Apply**

Run, in `terraform/authentik`:

```bash
tofu apply
```

Expected: `Apply complete! Resources: 1 added, 0 changed, 0 destroyed` (or `0 added, 1 changed`), with the scope-mapping change applied to `gitops-authentik` state. Backend is TFC; apply runs locally and pushes state.

- [ ] **Step 5: Verify the emitted claim via userinfo**

Fetch the Authentik userinfo endpoint (as Grafana does) to confirm the `role` claim now reads `Viewer`. From the repo, first load the admin session. Use the OIDC `userinfo` endpoint — an unauthenticated call returns 401, so do an authenticated check the same way the running Grafana container resolves it. Option A (fastest, no interactive browser):

```bash
# Get an access token for the grafana application using Authentik token API
curl -s -X POST "https://auth.dominiksiejak.pl/application/o/token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "grafana:$(grep -oP '(?<=^GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=).*' /Users/Apple/Developer/s3lcsum/gitops/stacks/monitoring/grafana.env)" \
  -d "grant_type=client_credentials" | python3 -c 'import sys,json;print(json.load(sys.stdin))'
```

If the client is not allowed `client_credentials`, instead verify by logging into the Grafana UI once as `dreewniak@gmail.com` (Step 6), which is the authoritative path.

- [ ] **Step 6: Functional verification — OIDC user lands on Viewer**

Have the user log out of Grafana and back in (OIDC → Authentik). Then confirm org role:

```bash
U=$(grep '^GF_SECURITY_ADMIN_USER=' /Users/Apple/Developer/s3lcsum/gitops/stacks/monitoring/grafana.env | cut -d= -f2)
P=$(grep '^GF_SECURITY_ADMIN_PASSWORD=' /Users/Apple/Developer/s3lcsum/gitops/stacks/monitoring/grafana.env | cut -d= -f2)
curl -s -u "$U:$P" "https://grafana.dominiksiejak.pl/api/org/users" | python3 -m json.tool
```

Expected: the entry for `dreewniak@gmail.com` shows `"role": "Viewer"`. The `admin@localhost` entry still shows `"role": "Admin"`. No change to `grafana.env` was made.

- [ ] **Step 7: Commit**

```bash
cd /Users/Apple/Developer/s3lcsum/gitops
git add terraform/authentik/locals.tf docs/superpowers/specs/2026-08-15-grafana-readonly-design.md docs/superpowers/plans/2026-08-15-grafana-readonly.md
git commit -m "fix(authentik): force grafana role claim to Viewer for read-only Grafana"
```

> Note: the pre-existing uncommitted changes in `locals.tf` (hermes block), `stacks/monitoring/compose.yaml` and `stacks/monitoring/grafana/provisioning/alerting/alerting.yaml` are intentionally **not** part of this commit. Only stage the three named paths. If `git status` shows the spec/plan files were never tracked, confirm you want them committed alongside the terraform change. After committing, run `git status` — the OLD unrelated modifications must remain uncommitted.
