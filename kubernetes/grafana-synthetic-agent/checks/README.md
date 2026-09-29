# Synthetic login checks

Grafana Cloud Synthetic Monitoring k6 checks. Not applied by OpenTofu — the SM provider does not manage checks. Import once in the SM UI (or `POST /api/v1/check` on `synthetic-monitoring-api-eu-west.grafana.net`).

Probe: private probe `Jarocin | Home` only. Public probes cannot reach these hosts. Agent image must be `grafana/synthetic-monitoring-agent:<tag>-browser` only if you switch these to browser checks; the scripts here are HTTP and run on the current image. Enable the `k6` feature flag on the probe.

Secrets: Grafana SM secret store, referenced as `${secret:...}`. Do not commit credentials.

| Check | Job | Target | Probe | Env |
| --- | --- | --- | --- | --- |
| `jellyfin-ldap.js` | `jellyfin-ldap-login` | `https://jellyfin.dominiksiejak.pl` | `Jarocin \| Home` | `JELLYFIN_LDAP_USERNAME`, `JELLYFIN_LDAP_PASSWORD` |
| `hass-authentik.js` | `hass-authentik-login` | `https://hass.dominiksiejak.pl` | `Jarocin \| Home` | `HASS_OIDC_USERNAME`, `HASS_OIDC_PASSWORD` |
| `hass-geo.js` | `hass-geo-allow` | `https://hass.dominiksiejak.pl` | Frankfurt (DE). Add Warsaw if a PL probe exists. ES is also allowlisted. | `EXPECT=open` |
| `hass-geo.js` | `hass-geo-block` | `https://hass.dominiksiejak.pl` | public US probe | `EXPECT=blocked` |
| `traefik-edge.js` | `traefik-wan-timeout` | `https://traefik.dominiksiejak.pl` | public probe not on `allowed-wan` | `EXPECT=timeout` |
| `traefik-edge.js` | `traefik-forward-auth` | `https://traefik.dominiksiejak.pl` | `Jarocin \| Home` (LAN, not WAN) | `EXPECT=forward-auth` |

Jellyfin posts `Users/AuthenticateByName`. A 200 with `AccessToken` means the LDAP plugin accepted the Authentik password. A 401 means the account was rejected.

Home Assistant starts at `/auth/authorize` and must 302 to `auth.dominiksiejak.pl`, then the Authentik flow executor must accept the same account and redirect back to `hass.dominiksiejak.pl`.

`hass-geo.js` hits the Cloudflare-proxied host. WAF allowlist is `PL`, `DE`, `ES` (`terraform/cloudflare` `country_allowlist`). Allowlisted probes must get HA (200/302/401). Other regions must get Cloudflare `403` with `Attention Required`. A missing US probe makes `hass-geo-block` meaningless — do not point it at Frankfurt.

`traefik-edge.js` hits the direct WAN path, not the tunnel. RouterOS drops sources absent from `allowed-wan` (timeout, status 0). A source on that list gets Authentik `302`. Cloudflare `403` is the country block, not the firewall. Use `EXPECT=forbidden` only if the probe is expected to die at the WAF instead of the firewall.

Suggested schedule: frequency 300s, timeout 60s, alert sensitivity `high`.
