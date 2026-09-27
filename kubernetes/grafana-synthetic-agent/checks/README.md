# Synthetic login checks

Grafana Cloud Synthetic Monitoring k6 checks. Not applied by OpenTofu — the SM provider does not manage checks. Import once in the SM UI (or `POST /api/v1/check` on `synthetic-monitoring-api-eu-west.grafana.net`).

Probe: private probe `Jarocin | Home` only. Public probes cannot reach these hosts. Agent image must be `grafana/synthetic-monitoring-agent:<tag>-browser` only if you switch these to browser checks; the scripts here are HTTP and run on the current image. Enable the `k6` feature flag on the probe.

Secrets: Grafana SM secret store, referenced as `${secret:...}`. Do not commit credentials.

| Check | Job | Target | Secrets |
| --- | --- | --- | --- |
| `jellyfin-ldap.js` | `jellyfin-ldap-login` | `https://jellyfin.dominiksiejak.pl` | `JELLYFIN_LDAP_USERNAME`, `JELLYFIN_LDAP_PASSWORD` |
| `hass-authentik.js` | `hass-authentik-login` | `https://hass.dominiksiejak.pl` | `HASS_OIDC_USERNAME`, `HASS_OIDC_PASSWORD` |

Jellyfin posts `Users/AuthenticateByName`. A 200 with `AccessToken` means the LDAP plugin accepted the Authentik password. A 401 means the account was rejected.

Home Assistant starts at `/auth/authorize` and must 302 to `auth.dominiksiejak.pl`, then the Authentik flow executor must accept the same account and redirect back to `hass.dominiksiejak.pl`.

Suggested schedule: frequency 300s, timeout 60s, alert sensitivity `high`.
