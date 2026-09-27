---
description: Run make check in one OpenTofu module. No plan, no apply.
agent: tofu
subtask: true
---

Run `make -C terraform/$1 check` only.

Refuse if `$1` is empty, `postgres`, `portainer`, or not a directory under `terraform/` that includes `terraform/base.Makefile`.

Do not run plan, apply, or destroy. Do not SSH. Do not write `defaults.auto.tfvars`. Do not read `*.env` or `*.tfvars`.

Report the make exit status and the failing check name. Do not fix unless the user asks.
