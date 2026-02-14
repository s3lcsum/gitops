import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: 1,
  duration: "10s",
};

export default function () {
  const grafanaBase = "https://grafana.lake.dominiksiejak.pl/";
  const loginStart = `${grafanaBase}login/generic_oauth`;

  const entryResponse = http.get(grafanaBase);
  check(entryResponse, {
    "grafana entry responds": (r) => r.status === 200 || r.status === 302,
  });

  const oauthResponse = http.get(loginStart, { redirects: 5 });
  check(oauthResponse, {
    "oauth login redirects to authentik": (r) =>
      r.status === 200 && r.url.includes("auth.lake.dominiksiejak.pl"),
  });

  const loginPage = oauthResponse;
  let csrfToken = "";
  const csrfMatch = loginPage.body.match(
    /name="csrfmiddlewaretoken"\s+value="([^"]+)"/,
  );
  if (csrfMatch) csrfToken = csrfMatch[1];

  check(loginPage, {
    "authentik login page loaded": (r) => r.status === 200,
    "authentik csrf token present": () => csrfToken.length > 0,
  });

  // Stage 1: Identification
  const idPayload = {
    csrfmiddlewaretoken: csrfToken,
    uid: "testing",
  };
  const idResponse = http.post(loginPage.url, idPayload, {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Referer: loginPage.url,
    },
    redirects: 5,
  });

  check(idResponse, {
    "authentik identification stage accepted": (r) => r.status === 200,
  });

  // Stage 2: Password
  const passPayload = {
    csrfmiddlewaretoken: csrfToken,
    password: "monty5averted@RECENTLY",
  };

  const loginResponse = http.post(loginPage.url, passPayload, {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Referer: loginPage.url,
    },
    redirects: 10,
  });
  check(loginResponse, {
    "authentik login accepted": (r) => r.status === 200 || r.status === 302,
    "redirects back to grafana": (r) =>
      r.url.includes("grafana.lake.dominiksiejak.pl"),
  });

  const grafanaHome = http.get(grafanaBase);
  check(grafanaHome, {
    "grafana home reachable": (r) => r.status === 200,
    "grafana session is logged in": (r) =>
      /"loggedIn":true/.test(r.body),
  });

  sleep(1);
}
