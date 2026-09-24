---
description: Generate changelog, commit changes grouped by conventional-commit type, push to main. Use when user says "/release" or wants to cut a release.
---

# Release automation

You are a release automation agent. Your job: summarize recent work, write a changelog entry, commit changes as well-structured conventional commits, and push.

## Rules

- **Changelog**: single compact paragraph per day, written in natural conversational English. Technically precise—include versions, paths, config keys. Casual but professional, no forced slang ("yeeted", "whining", "ripped out" style is out). No emojis, no bullet points, no code blocks. Explain what changed and why briefly.
- **Commits**: use conventional commit format (`type(scope): message`). Group related changes together.
- **Push**: always to `origin main`.

## Workflow

### 1. Detect last release

Read `README.md`. Find the first `### DD.MM.YYYY` line in the Changelog section. That is the last release date. Parse the date—format is `DD.MM.YYYY`. Convert to `YYYY-MM-DD` for git.

If no prior entry found, use `git log --oneline` from the beginning of the repo.

### 2. Gather changes

Two sources:

a) **Committed changes since last release** — run:
   `git log --oneline --since="YYYY-MM-DD" --format="%h %s"`

b) **Uncommitted changes in working tree** — run:
   `git status --short`

### 3. Categorize

Group all changes by conventional-commit type:
- `feat` → **Features**
- `fix` → **Bug Fixes**
- `refactor` → **Refactoring**
- `chore` → **Chores**
- `docs` → **Documentation**
- `perf` → **Performance**
- `ci` → **CI/CD**
- `test` → **Testing**
- `style` → **Style**
- `revert` → **Reverts**

For uncommitted changes, read the diffs (`git diff --stat` / `git diff`) and assign each file to the most appropriate type based on what the change does.

### 4. Write changelog entry

If today's date (`DD.MM.YYYY`) already has a `###` header in README.md, **append** to that existing entry (merge the new paragraph in).

Otherwise, **insert** a new entry at the top of the Changelog section (right after the `## Changelog` header, before the most recent `###` line).

Format:
```
### DD.MM.YYYY

One compact paragraph. A few sentences. Describes what was done across all commits and uncommitted changes. Covers what changed and why. Uses backtick for paths/commands. Natural casual English, no forced slang. No emojis. No bullet points. No code blocks.
```

### 5. Commit

Stage everything first: `git add -A`.

**Default mode (single commit):**
```
chore(release): DD.MM.YYYY

<grouped body listing changes by type>
```
The body lists each group with a short summary of what changed.

**If `$ARGUMENTS` contains `--split`:**
Create one commit per conventional-commit type that has changes. Order: feat first, then fix, refactor, chore, docs, perf, ci, test, style, revert. Each commit message follows the format `type(scope): description` based on what the grouped changes are about.

For the README.md changelog update: if using `--split`, include it in a `chore(release): DD.MM.YYYY` commit as the last commit. If single mode, it goes in the release commit body.

### 6. Push

`git push origin main`

## Edge cases

| Situation | Action |
|---|---|
| No new changes since last release | Abort with message, nothing to release |
| Dirty working tree | Clean is ideal. If dirty, warn but proceed — the AI will describe the dirty changes in the changelog and commit them |
| Today's date already has changelog entry | Append/merge into existing entry, don't duplicate the header |
| No git remote or push fails | Abort with the error message, don't force push |
| `--date DD.MM.YYYY` in arguments | Use this date instead of today for the changelog header |
| Multiple days of commits since last release | Create one `### DD.MM.YYYY` paragraph per day, newest first |
