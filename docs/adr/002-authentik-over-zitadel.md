# ADR003: Choose Authentik over ZITADEL and Keycloak

- **Status**: Accepted
- **Date**: 2025-12-15
- **Deciders**: @s3lcsum

## Context

We need a self-hosted identity platform that is the **single source of truth for users** and can be managed **declaratively via Terraform**, while still supporting legacy and homelab constraints (not everything speaks OIDC).

In August 2025, we switched from Authentik to ZITADEL due to ongoing configuration issues with Authentik's flows and stages. ZITADEL seemed promising (actively developed, modern architecture, and looked simpler on paper).

Separately, we also evaluated Keycloak (industry standard) and have prior experience running it.

### Must-have requirements

- **Single source of truth for users**
- **Users manageable from Terraform**
- **Service accounts** (for automation/non-human access)
- **Proxy / forward-auth** for applications that are neither LDAP nor OAuth/OIDC capable
- **Good Terraform provider**
- **Ease of integrations** (rich documentation, stable patterns, community knowledge)
- **WebAuthn** support (including good compatibility with 1Password)
- **LDAP support is mandatory** because some critical services (e.g. Synology) do not support OAuth/OIDC

### What went wrong / what we learned

After several months of running ZITADEL, we hit significant issues:

- Documentation was sparse and often outdated
- Terraform provider was less mature than Authentik's (more manual drift)
- Some features that worked out-of-the-box in Authentik required workarounds
- Community support was limited compared to Authentik's larger user base
- Integration with existing services (especially forward-auth for Traefik) was more complex
- LDAP integration was not where we needed it to be for an environment where LDAP is mandatory

Meanwhile, Authentik continued to improve, and we had backups of our previous configuration and operational experience with outposts/forward-auth.

## Decision

Choose Authentik as the primary identity platform (IdP + LDAP + forward-auth). Restore the previous configuration from backup and update the PostgreSQL database setup to handle Authentik's credentials properly.

Key factors:

- **Meets must-haves best overall**: strong coverage for LDAP + OIDC/SAML + forward-auth in one stack
- **Terraform support**: The Authentik Terraform provider is well-maintained and practical for managing apps/providers
- **Proxy/outpost model**: outposts make it straightforward to protect "non-OAuth / non-LDAP" apps behind Traefik
- **Documentation & community**: richer docs and more real-world examples for homelab-style integrations
- **WebAuthn**: supports modern MFA and passkeys (including 1Password)
- **Existing knowledge**: we already know how to operate it (even if flows/stages are complex)

## Alternatives Considered

### Alternative 1: Stay with ZITADEL

Continue investing in ZITADEL and work through the issues.

**Why not**: The time investment wasn't paying off. Each new integration required significant research, and the Terraform provider gaps meant more manual configuration — exactly what we were trying to avoid. Most importantly, LDAP support/integration is not strong enough for an environment where LDAP is non-negotiable (e.g. Synology).

### Alternative 2: Keycloak

Keycloak is the industry standard for self-hosted identity management.

**Why not**:

- LDAP integration was painful in practice (and LDAP is mandatory due to Synology not supporting OAuth/OIDC)
- Configuration and integration work tended to be more complex than we want for this environment
- Heavier operational footprint (Java stack) than necessary for our needs

### Alternative 3: Authelia

Lightweight forward-auth solution that's fully YAML-configurable.

**Why not**: We actually tried Authelia briefly (see changelog entry from May 2025). While simpler, it lacks the full IdP features we need — no built-in user management UI, limited OIDC provider capabilities, no LDAP outpost.

## Consequences

### Positive

- Back to a known, working configuration
- Better Terraform support for managing providers, applications, and outposts
- Larger community for troubleshooting
- Full-featured IdP: OIDC, SAML, LDAP, forward auth all in one place

### Negative

- Lost several months of ZITADEL investment
- Had to clean up ZITADEL remnants from Terraform code
- Authentik's flows/stages are still complex to configure via Terraform (some manual UI work still needed)

### Neutral

- Updated PostgreSQL configuration to handle Authentik database credentials
- Re-deployed Authentik outpost for Docker environments
- Updated `terraform/authentik/` module

## References

- [Authentik Documentation](https://goauthentik.io/docs/)
- [Authentik Terraform Provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- Changelog entries: 2025-08-23 (ZITADEL switch), 2025-12-15 (Authentik return)

