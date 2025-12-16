# ADR-0001: Use Traefik instead of Nginx Proxy Manager

- **Status**: Accepted
- **Date**: 2025-07-07
- **Deciders**: @s3lcsum

## Context

The homelab needed a reverse proxy for multiple Docker services (routing + TLS). Options considered: **Traefik** and **Nginx Proxy Manager (NPM)**.

## Decision

Use **Traefik** as the primary reverse proxy.

Chosen primarily for **Docker label integration** (easy, consistent routing per-service) and strong **ACME / Let’s Encrypt** automation.

## Alternatives Considered

### Nginx Proxy Manager (NPM)

Not chosen because it’s **UI/database driven**, harder to version-control and automate, and doesn’t fit a **label-driven** workflow as well.

## Consequences

### Positive

- Routing defined via **Docker labels**.
- Automated **ACME / Let’s Encrypt** certificates.

### Negative

- More learning/debugging via logs than a UI.
- Migration work to update existing services/labels.

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)

