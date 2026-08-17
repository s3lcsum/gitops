#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/jellyfin-plugin.sh"

LDAP_ID="$("$SCRIPT_DIR/jellyfin-plugin.sh" _id "LDAP-Auth" 2>/dev/null || true)"
[ -z "${LDAP_ID:-}" ] && LDAP_ID="958aad6637844d2ab89aa7b6fab6e25c"
SSO_ID="505ce9d1-d916-42fa-86ca-673ef241d7df"

echo "LDAP plugin Id: $LDAP_ID"
echo "SSO plugin GUID: $SSO_ID"

# ---- LDAP-Auth (official Jellyfin plugin) ----
# Uses the generic /Plugins/{id}/Configuration endpoint. Live schema field names:
# LdapServer, LdapPort, UseSsl, UseStartTls, LdapBaseDn, LdapUsernameAttribute,
# LdapSearchFilter, LdapAdminFilter, LdapBindUser/LdapBindPassword (search bind).
echo "== LDAP-Auth: current config =="
LDAP_CFG="$(jf_api GET "/Plugins/$LDAP_ID/Configuration")"
echo "$LDAP_CFG" > /tmp/ldapcfg.json

LDAP_NEW="$(python3 - "$LDAP_CFG" <<'PY'
import json,sys,os
cfg=json.loads(sys.argv[1])
cfg["LdapServer"]="192.168.89.253"
cfg["LdapPort"]=389
cfg["UseSsl"]=False
cfg["LdapBindUser"]="cn=jellyfin,ou=users,dc=dominiksiejak,dc=pl"
# Preserve the existing (user-configured) bind password unless one is supplied.
# LDAP_SVC_PASSWORD is empty by default, so never clobber it with "".
if os.environ.get("LDAP_SVC_PASSWORD"):
    cfg["LdapBindPassword"]=os.environ.get("LDAP_SVC_PASSWORD")
cfg["LdapBaseDn"]="ou=users,dc=dominiksiejak,dc=pl"
cfg["LdapUsernameAttribute"]="cn"
cfg["LdapSearchFilter"]="(memberOf=cn=users,ou=groups,dc=dominiksiejak,dc=pl)"
cfg["LdapAdminFilter"]="(memberOf=cn=admins,ou=groups,dc=dominiksiejak,dc=pl)"
cfg["CreateUsersFromLdap"]=True
print(json.dumps(cfg))
PY
)"
echo "== LDAP-Auth: posting config =="
jf_api POST "/Plugins/$LDAP_ID/Configuration" "$LDAP_NEW" >/dev/null && echo "posted OK"
echo "== LDAP-Auth: effective config after post =="
jf_api GET "/Plugins/$LDAP_ID/Configuration" | python3 -m json.tool

# ---- SSO (Flowfin "Community SSO for Jellyfin") ----
# Does NOT honor the generic /Plugins/{id}/Configuration PUT. Providers are managed
# via the plugin's own admin API: POST /sso/OID/Add/{provider} (body = OidConfig).
# OidEndpoint must point at the full discovery document (/.well-known/openid-configuration).
# OidSecret is write-only/encrypted at rest; it reads back as null (expected).
# AllowPrivateNetworkAddresses=true is required: the plugin does its own DNS query through
# the LAN resolver, which resolves auth.dominiksiejak.pl to RFC1918 192.168.89.253, tripping
# the outbound SSRF guard otherwise.
echo "== SSO-Auth: posting 'authentik' provider via /sso/OID/Add =="
SSO_BODY="$(python3 - "$OIDC_CLIENT_SECRET" <<'PY'
import json,sys,os
secret=sys.argv[1]
print(json.dumps({
  "Enabled": True,
  "OidEndpoint": "https://auth.dominiksiejak.pl/application/o/jellyfin/.well-known/openid-configuration",
  "OidClientId": "jellyfin",
  "OidSecret": secret,
  "OidScopes": ["openid", "profile", "email", "groups"],
  "RoleClaim": "groups",
  "Roles": ["users"],
  "AdminRoles": ["admins"],
  "EnableAuthorization": True,
  "EnableAllFolders": True,
  "AllowPrivateNetworkAddresses": True,
  "BaseUrlOverride": "https://jellyfin.dominiksiejak.pl",
}))
PY
)"
jf_api POST "/sso/OID/Add/authentik" "$SSO_BODY" >/dev/null && echo "posted OK"
echo "== SSO-Auth: effective providers (OidSecret withheld=null) =="
jf_api GET "/sso/OID/Get" | python3 -m json.tool
echo "== SSO-Auth: connection test =="
jf_api GET "/sso/OID/Test/authentik" | python3 -m json.tool

