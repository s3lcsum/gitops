import { check, fail } from "k6";
import http from "k6/http";

// Direct :443 is RouterOS allowed-wan, then Authentik forward-auth.
// Unlisted WAN sources time out at the firewall. Listed sources get 302
// to auth.dominiksiejak.pl. Cloudflare country block is 403.
const expect = __ENV.EXPECT || "timeout";

export default function () {
  const res = http.get("https://traefik.dominiksiejak.pl/dashboard/", {
    redirects: 0,
    timeout: "15s",
    tags: { name: "traefik-edge" },
  });

  const timedOut = res.error_code !== 0 && res.status === 0;
  const cloudflareBlock =
    res.status === 403 && (res.body || "").indexOf("Attention Required") !== -1;
  const authentikRedirect =
    res.status === 302 &&
    (res.headers.Location || "").indexOf("https://auth.dominiksiejak.pl/") === 0;

  if (expect === "timeout") {
    const ok = check(res, {
      "unlisted WAN source times out": () => timedOut,
    });
    if (!ok) {
      fail(`expected firewall timeout, got HTTP ${res.status} error ${res.error_code}`);
    }
    return;
  }

  if (expect === "forbidden") {
    const ok = check(res, {
      "country block or denied": () => cloudflareBlock || res.status === 403,
    });
    if (!ok) {
      fail(`expected 403, got HTTP ${res.status}`);
    }
    return;
  }

  if (expect === "forward-auth") {
    const ok = check(res, {
      "authentik forward-auth redirect": () => authentikRedirect,
    });
    if (!ok) {
      fail(`expected authentik redirect, got HTTP ${res.status}`);
    }
    return;
  }

  fail(`EXPECT must be timeout, forbidden, or forward-auth, got ${expect}`);
}
