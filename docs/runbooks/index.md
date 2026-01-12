# RB001: Runbooks

Runbooks are incident response procedures. When something breaks, these documents help you diagnose and fix it quickly.

**Written for "3am brain":** Clear, sequential steps. No ambiguity. Copy-paste commands where possible.

## Available Runbooks

| Runbook | When to Use |
|---------|-------------|
| [Initialize Vault](initialize-vault.md) | Vault data volume recreated; permission denied on `/vault/data/*`; raft storage empty |

## Runbook Format

Each runbook follows this structure:

1. **Symptoms**: What does the problem look like?
2. **Quick Check**: Fast diagnostics to confirm the issue
3. **Resolution Steps**: Step-by-step fix
4. **Verification**: How to confirm it's fixed
5. **Escalation**: What to do if this doesn't work

## When to Write a New Runbook

Write a runbook when:

- You've fixed the same issue more than once
- The fix involves multiple steps that are easy to forget
- Someone else might need to fix this while you're unavailable
- The issue is time-sensitive (production impact)

## Tips for Using Runbooks

- **Don't skip steps** — even if you think you know what's wrong
- **Copy-paste commands** — don't retype, you'll make mistakes
- **Document what you find** — add notes if the runbook needs updating
- **Time yourself** — if a runbook takes too long, it needs improvement

