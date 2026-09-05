/**
 * Dynamic URL redirector for https://url.dominiksiejak.pl
 *
 * Destinations live in Workers KV (binding LINKS, key links:v1).
 * Edit terraform/cloudflare/shorturl-links.json and apply.
 */

const LINKS_KEY = "links:v1";
const ALLOWED_PROTOCOLS = new Set(["https:", "mailto:"]);

function text(body, status = 200) {
  return new Response(body, {
    status,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function empty(status = 200, extra = {}) {
  return new Response(null, {
    status,
    headers: {
      "Cache-Control": "no-store",
      ...extra,
    },
  });
}

function isAllowedDestination(destination) {
  try {
    const parsed = new URL(destination);
    return ALLOWED_PROTOCOLS.has(parsed.protocol);
  } catch {
    return false;
  }
}

export default {
  async fetch(request, env) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method Not Allowed", {
        status: 405,
        headers: {
          Allow: "GET, HEAD",
          "Cache-Control": "no-store",
        },
      });
    }

    const url = new URL(request.url);
    const path =
      url.pathname === "/" ? "/" : url.pathname.replace(/\/+$/, "");

    console.info({
      event: "redirect_request",
      method: request.method,
      path,
    });

    if (path === "/") {
      if (request.method === "HEAD") {
        return empty(200);
      }
      return text("Dominik Siejak — URL shortener\n");
    }

    const links = (await env.LINKS.get(LINKS_KEY, { type: "json" })) || {};
    const destination = links[path];
    if (!destination) {
      console.warn({
        event: "link_not_found",
        method: request.method,
        path,
      });
      return request.method === "HEAD"
        ? empty(404)
        : text("Link not found.", 404);
    }

    if (!isAllowedDestination(destination)) {
      console.warn({
        event: "link_blocked",
        method: request.method,
        path,
      });
      return request.method === "HEAD"
        ? empty(502)
        : text("Link blocked.", 502);
    }

    return empty(302, { Location: destination });
  },
};
