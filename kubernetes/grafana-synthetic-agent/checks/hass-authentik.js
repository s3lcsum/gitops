import { check, fail } from "k6";
import http from "k6/http";

const username = __ENV.HASS_OIDC_USERNAME;
const password = __ENV.HASS_OIDC_PASSWORD;

export default function () {
  if (!username || !password) {
    fail("HASS_OIDC_USERNAME and HASS_OIDC_PASSWORD must be set");
  }

  const jar = http.cookieJar();
  const authorize = http.get(
    "https://hass.dominiksiejak.pl/auth/authorize?" +
      "response_type=code" +
      "&client_id=https://hass.dominiksiejak.pl/" +
      "&redirect_uri=https://hass.dominiksiejak.pl/auth/openid/callback",
    { redirects: 0, tags: { name: "hass-authorize" } },
  );

  const location = authorize.headers.Location || "";
  const toAuthentik = check(authorize, {
    "hass redirects to authentik": (r) =>
      r.status === 302 && location.indexOf("https://auth.dominiksiejak.pl/") === 0,
  });
  if (!toAuthentik) {
    fail(`hass did not redirect to authentik: HTTP ${authorize.status} ${location}`);
  }

  const flow = http.get(location, {
    jar,
    tags: { name: "authentik-flow" },
  });
  const flowOk = check(flow, {
    "authentik flow 200": (r) => r.status === 200,
    "authentik flow body": (r) =>
      (r.body || "").indexOf("ak-stage-identification") !== -1 ||
      (r.body || "").indexOf("authentication") !== -1,
  });
  if (!flowOk) {
    fail(`authentik flow did not render: HTTP ${flow.status}`);
  }

  const flowMatch = location.match(/\/flow\/([^/?]+)/);
  if (!flowMatch) {
    fail("authentik redirect missing flow id");
  }

  const identified = http.post(
    `https://auth.dominiksiejak.pl/api/v3/flows/executor/${flowMatch[1]}/`,
    JSON.stringify({ uid_field: username }),
    {
      jar,
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      tags: { name: "authentik-identify" },
    },
  );
  if (identified.status !== 200) {
    fail(`authentik identify failed: HTTP ${identified.status}`);
  }

  const authed = http.post(
    `https://auth.dominiksiejak.pl/api/v3/flows/executor/${flowMatch[1]}/`,
    JSON.stringify({ password: password }),
    {
      jar,
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      redirects: 0,
      tags: { name: "authentik-password" },
    },
  );

  let callback = "";
  try {
    callback = authed.json("to") || "";
  } catch (e) {
    callback = "";
  }
  if (!callback && (authed.status === 302 || authed.status === 301)) {
    callback = authed.headers.Location || "";
  }

  const loggedIn = check(authed, {
    "authentik accepted password": (r) => r.status === 200 || r.status === 302,
    "redirects back to hass": () => callback.indexOf("https://hass.dominiksiejak.pl/") === 0,
  });
  if (!loggedIn) {
    fail(`authentik login failed: HTTP ${authed.status}`);
  }
}
