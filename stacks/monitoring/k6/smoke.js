import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  vus: 1,
  duration: "10s",
};

export default function () {
  const host = "auth.lake.dominiksiejak.pl";
  const httpUrl = `http://${host}/`;
  const httpsUrl = `https://${host}/`;

  const redirectResponse = http.get(httpUrl, { redirects: 0 });
  check(redirectResponse, {
    "http redirects to https": (r) =>
      (r.status === 301 || r.status === 302 || r.status === 307 || r.status === 308) &&
      String(r.headers.Location || "").startsWith("https://"),
  });

  const landingResponse = http.get(httpsUrl);
  check(landingResponse, {
    "https responds": (r) => r.status === 200 || r.status === 302,
  });

  const loginUrl = landingResponse.url.includes("/if/flow/")
    ? landingResponse.url
    : `${httpsUrl}if/flow/default-authentication-flow/`;

  const loginPage = http.get(loginUrl);
  let csrfToken = "";
  const csrfMatch = loginPage.body.match(
    /name="csrfmiddlewaretoken"\s+value="([^"]+)"/,
  );
  if (csrfMatch) csrfToken = csrfMatch[1];

  check(loginPage, {
    "login page loaded": (r) => r.status === 200,
    "csrf token present": () => csrfToken.length > 0,
  });

  // Stage 1: Identification
  const idPayload = {
    csrfmiddlewaretoken: csrfToken,
    uid: "testing",
  };
  const idResponse = http.post(loginUrl, idPayload, {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Referer: loginUrl,
    },
    redirects: 5,
  });

  check(idResponse, {
    "identification stage accepted": (r) => r.status === 200,
  });

  // Stage 2: Password
  const passPayload = {
    csrfmiddlewaretoken: csrfToken,
    password: "monty5averted@RECENTLY",
  };
  const loginResponse = http.post(loginUrl, passPayload, {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Referer: loginUrl,
    },
    redirects: 5,
  });

  check(loginResponse, {
    "login request accepted": (r) => r.status === 200 || r.status === 302,
  });

  const portalResponse = http.get(`${httpsUrl}if/user/`);
  check(portalResponse, {
    "user portal available": (r) => r.status === 200,
    "grafana app visible": (r) => /Grafana/i.test(r.body),
  });

  sleep(1);
}
