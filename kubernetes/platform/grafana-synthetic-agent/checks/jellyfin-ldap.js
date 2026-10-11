import { check, fail } from "k6";
import http from "k6/http";

const username = __ENV.JELLYFIN_LDAP_USERNAME;
const password = __ENV.JELLYFIN_LDAP_PASSWORD;

export default function () {
  if (!username || !password) {
    fail("JELLYFIN_LDAP_USERNAME and JELLYFIN_LDAP_PASSWORD must be set");
  }

  const res = http.post(
    "https://jellyfin.dominiksiejak.pl/Users/AuthenticateByName",
    JSON.stringify({ Username: username, Pw: password }),
    {
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-Emby-Authorization":
          'MediaBrowser Client="GrafanaSM", Device="homelab-probe", DeviceId="homelab-probe", Version="1.0.0"',
      },
      tags: { name: "jellyfin-ldap-login" },
    },
  );

  const ok = check(res, {
    "ldap login status 200": (r) => r.status === 200,
    "access token present": (r) => {
      try {
        return Boolean(r.json("AccessToken"));
      } catch (e) {
        return false;
      }
    },
  });

  if (!ok) {
    fail(`jellyfin ldap login failed: HTTP ${res.status}`);
  }
}
