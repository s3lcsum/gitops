# Playbooks

Playbooks are repeatable operational tasks that aren't emergencies. Think of these as Standard Operating Procedures (SOPs) for routine maintenance and changes.

Unlike [runbooks](../runbooks/index.md) (which are for incidents), playbooks are for planned work.

## Available Playbooks

| Playbook | When to Use |
|----------|-------------|
| [Upgrade a Stack](upgrade-stack.md) | Updating a service to a newer version |
| [Bootstrap New Host](bootstrap-new-host.md) | Setting up a new server from scratch |

## Playbook vs Runbook

| Aspect | Playbook | Runbook |
|--------|----------|---------|
| **Timing** | Planned, scheduled | Reactive, incident-driven |
| **Pace** | Can take your time | Time-sensitive |
| **Rollback** | Plan for it | May need to improvise |
| **Documentation** | Before you start | While you fix |

## Writing Good Playbooks

1. **Prerequisites first**: What do you need before starting?
2. **Estimated time**: How long should this take?
3. **Rollback plan**: How to undo if something goes wrong?
4. **Verification steps**: How to confirm success?
5. **Post-task cleanup**: Any follow-up needed?

