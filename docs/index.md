# Documentation

Welcome to the documentation for the Home Infrastructure as Code repository. This docs hub contains architectural decisions, operational procedures, and guides for working with this codebase.

## What's Here

### [Architecture Decision Records (ADRs)](adr/index.md)

Documented decisions about significant architectural choices — what we decided, why, and what alternatives were considered. ADRs help future-you (and others) understand the reasoning behind the current setup.

### [Golden Paths](golden-paths/index.md)

Step-by-step guides for common tasks: adding a new Docker stack, creating a Terraform module, setting up a service behind Traefik. These are the "happy paths" — the recommended way to do things in this repo.

### [Runbooks](runbooks/index.md)

Incident response procedures. When something breaks, these documents help you diagnose and fix it quickly. Written for "3am brain" — clear, sequential steps.

### [Playbooks](playbooks/index.md)

Repeatable operational tasks that aren't emergencies: upgrading a stack, bootstrapping a new host, rotating secrets. Think of these as SOPs (Standard Operating Procedures).

### [Architecture](architecture/index.md)

High-level system diagrams using C4 model conventions. Understand how the pieces fit together before diving into the code.

---

## Quick Links

| Resource | Description |
|----------|-------------|
| [README](../README.md) | Main project overview, services list, infrastructure details |
| [stacks/](../stacks/) | Docker Compose stack definitions |
| [terraform/](../terraform/) | Infrastructure as Code modules |
| [terraform/netbox/](../terraform/netbox/) | NetBox inventory management |

---

## How to Use These Docs

**Locally:** These docs are plain Markdown and render fine in GitHub/GitLab. For a nicer experience, run MkDocs locally:

```bash
pip install mkdocs-material
mkdocs serve
```

Then open `http://localhost:8000`.

**Online:** The docs are automatically built and deployed to GitHub Pages via GitHub Actions on every push to `main`.

---

## Contributing to Docs

When adding new documentation:

1. **ADRs**: Use the template at `adr/0000-template.md`. Number sequentially.
2. **Golden Paths**: Focus on the "what" and "how", not the "why" (that's for ADRs).
3. **Runbooks**: Write for someone who's tired and stressed. Be explicit.
4. **Playbooks**: Include verification steps. Assume nothing.

Keep docs up to date when you change the infrastructure — stale docs are worse than no docs.

