import { check, fail } from "k6";
import http from "k6/http";

// Cloudflare WAF allows PL, DE, ES. Everything else is blocked.
// Run this script from one probe per region. Pass EXPECT=open on PL/DE/ES
// probes and EXPECT=blocked on US (and any other non-allowlisted) probes.
const expect = __ENV.EXPECT || "open";

export default function () {
  const res = http.get("https://hass.dominiksiejak.pl/", {
    redirects: 0,
    timeout: "20s",
    tags: { name: "hass-geo" },
  });

  const blocked =
    res.status === 403 && (res.body || "").indexOf("Attention Required") !== -1;

  if (expect === "blocked") {
    const ok = check(res, {
      "non-allowlisted country blocked": () => blocked,
    });
    if (!ok) {
      fail(`expected Cloudflare 403, got HTTP ${res.status}`);
    }
    return;
  }

  if (expect !== "open") {
    fail(`EXPECT must be open or blocked, got ${expect}`);
  }

  const ok = check(res, {
    "allowlisted country reaches hass": (r) =>
      r.status === 200 || r.status === 302 || r.status === 401,
    "not a cloudflare country block": () => !blocked,
  });
  if (!ok) {
    fail(`hass unreachable from allowlisted probe: HTTP ${res.status}`);
  }
}
