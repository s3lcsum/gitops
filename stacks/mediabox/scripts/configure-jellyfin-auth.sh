#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/jellyfin-plugin.sh"

LDAP_ID="$("$SCRIPT_DIR/jellyfin-plugin.sh" _id "LDAP-Auth" 2>/dev/null || true)"
[ -z "${LDAP_ID:-}" ] && LDAP_ID="958aad6637844d2ab89aa7b6fab6e25c"

echo "LDAP plugin Id: $LDAP_ID"

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
