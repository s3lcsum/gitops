---
description: Plan one OpenTofu module. Stop before apply.
agent: tofu
subtask: true
---

Run `make -C terraform/$1 plan` only.

Refuse if `$1` is empty, `postgres`, `portainer`, or not a directory under `terraform/` that includes `terraform/base.Makefile`.

Do not pass `-auto-approve`. Do not run apply or destroy. Do not SSH. Do not write `defaults.auto.tfvars`. Do not read `*.env` or `*.tfvars`.

Print the plan summary. Stop. Do not apply unless the user asks in a later message.
