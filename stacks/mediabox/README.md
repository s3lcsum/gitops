# mediabox

## Jellyfin auth (LDAP only)

Jellyfin authenticates users against Authentik via the **LDAP-Auth** plugin
(provided by the **catalog-installed** official plugin; version floats with the
Jellyfin plugin catalog). Its config is managed via the Jellyfin UI/admin API,
and it runs alongside the default local admin account (which is preserved).

The LDAP plugin is **not** repo-pinned (no bind mount) — it is installed from
the Jellyfin plugin catalog. Configuration is applied from this repo via the
`configure-jellyfin-auth.sh` helper using the Jellyfin admin API.

### Admin API key (required)

Create a Jellyfin API key via **Dashboard → API Keys**, or reissue from
`secrets`. It is consumed **only at apply time from env** and is never
committed. Populate `stacks/mediabox/.jellyfin.secrets` from
`.jellyfin.secrets.example`:

```
JF_API_KEY=<your api key>
LDAP_SVC_PASSWORD=<svc_jellyfin app_password token, if required>
```

`.jellyfin.secrets` is gitignored. `LDAP_SVC_PASSWORD` comes from Authentik
tofu state: `authentik_token.service_account_tokens["svc_jellyfin"]`.

### Configure LDAP

```bash
bash stacks/mediabox/scripts/configure-jellyfin-auth.sh
```

The helper (`jellyfin-plugin.sh`) sources `.jellyfin.secrets` and wraps the
Jellyfin admin API.

**LDAP-Auth** (official Jellyfin plugin) is configured through the generic
`GET`/`POST /Plugins/{id}/Configuration` endpoint. Live-schema fields:
`LdapServer`, `LdapPort`, `UseSsl`, `LdapBaseDn`, `LdapUsernameAttribute`,
`LdapSearchFilter`, `LdapAdminFilter`, `LdapBindUser`/`LdapBindPassword`.

Known-good values (Authentik LDAP outpost, `bind_mode=direct`):

- `LdapServer` = `192.168.89.253` (the LDAP outpost host port 389 — **not**
  `auth.dominiksiejak.pl`, which is the HTTPS web host with no LDAP listener)
- `LdapPort` = `389`, `UseSsl` = `false`
- `LdapBindUser` = `cn=jellyfin,ou=users,dc=dominiksiejak,dc=pl`
- `LdapBaseDn` = `ou=users,dc=dominiksiejak,dc=pl`
- `LdapSearchFilter` = `(memberOf=cn=users,ou=groups,dc=dominiksiejak,dc=pl)`
- `LdapAdminFilter` = `(memberOf=cn=admins,ou=groups,dc=dominiksiejak,dc=pl)`

The helper preserves the existing bind password unless `LDAP_SVC_PASSWORD` is
set (so it never clobbers a working password with an empty string).
