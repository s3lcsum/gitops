# mediabox

## Jellyfin auth (SSO + LDAP)

Task 4 configures two jellyfin login paths **in addition to** the default local
admin account (which is preserved):

- **Community SSO for Jellyfin** (`Jellyfin.Plugin.SSO`) — OIDC bridge to
  Authentik (provider `authentik`).
- **LDAP Authentication** (`ldapauth`) — Authentik LDAP bind for login.

The plugin binaries live in `jellyfin-plugins/` and load from
`/config/data/plugins/<Name>_<version>/` on container start.

### Admin API key (required)

Create a Jellyfin API key via **Dashboard → API Keys**, or reissue from
`secrets`. It is consumed **only at apply time from env** and is never
committed. Populate `stacks/mediabox/.jellyfin.secrets` from
`.jellyfin.secrets.example`:

```
JF_API_KEY=<your api key>
OIDC_CLIENT_SECRET=<authentik jellyfin provider client secret>
LDAP_SVC_PASSWORD=<svc_jellyfin app_password token, if required>
```

`.jellyfin.secrets` is gitignored. `OIDC_CLIENT_SECRET` and
`LDAP_SVC_PASSWORD` come from Authentik tofu state:
`authentik_provider_oauth2.oauth2["jellyfin"]` and
`authentik_token.service_account_tokens["svc_jellyfin"]`.

### Configure the plugins

```bash
bash stacks/mediabox/scripts/configure-jellyfin-auth.sh
```

The helper (`jellyfin-plugin.sh`) sources `.jellyfin.secrets` and wraps the
Jellyfin admin API.

**LDAP-Auth** (official Jellyfin plugin) is configured through the generic
`GET`/`POST /Plugins/{id}/Configuration` endpoint. Live-schema fields:
`LdapServer`, `LdapPort`, `UseSsl`, `LdapBaseDn`, `LdapUsernameAttribute`,
`LdapSearchFilter`, `LdapAdminFilter`, `LdapBindUser`/`LdapBindPassword`.

**Community SSO for Jellyfin** (Flowfin) does **not** honor the generic
`/Plugins/{id}/Configuration` PUT. Its providers are managed via the plugin's
own admin API: `POST /sso/OID/Add/{provider}` (body = one `OidConfig` object).
`OidEndpoint` must point at the **full discovery document**
(`.../.well-known/openid-configuration`), not the issuer base. `OidSecret` is
write-only and AES-encrypted at rest, so it reads back as `null` (expected).
`AllowPrivateNetworkAddresses: true` is required because the plugin performs its
own DNS query through the LAN resolver, which maps `auth.dominiksiejak.pl` to
RFC1918 `192.168.89.253` and would otherwise trip the outbound SSRF guard; this
is audit-logged as a documented downgrade.
