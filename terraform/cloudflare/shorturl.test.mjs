import assert from "node:assert/strict";
import { test } from "node:test";
import worker from "./shorturl.js";

const LINKS = {
  "/github": "https://github.com/s3lcsum",
  "/email": "mailto:office@dominiksiejak.pl",
  "/evil": "javascript:alert(1)",
};

function env(links = LINKS) {
  return {
    LINKS: {
      async get(_key, opts) {
        if (opts?.type === "json") return links;
        return JSON.stringify(links);
      },
    },
  };
}

async function hit(path, { method = "GET", accept } = {}) {
  const headers = {};
  if (accept) headers.Accept = accept;
  return worker.fetch(
    new Request(`https://url.dominiksiejak.pl${path}`, { method, headers }),
    env(),
  );
}

test("GET / does not dump destinations", async () => {
  const res = await hit("/");
  const body = await res.text();
  assert.equal(res.status, 200);
  assert.equal(body.includes("github.com"), false);
  assert.equal(body.includes("mailto:"), false);
  assert.equal(body.includes("javascript:"), false);
});

test("HEAD / is empty and skips KV listing", async () => {
  const res = await hit("/", { method: "HEAD" });
  assert.equal(res.status, 200);
  assert.equal(await res.text(), "");
});

test("GET /github redirects", async () => {
  const res = await hit("/github");
  assert.equal(res.status, 302);
  assert.equal(res.headers.get("Location"), "https://github.com/s3lcsum");
});

test("HEAD /github redirects with empty body", async () => {
  const res = await hit("/github", { method: "HEAD" });
  assert.equal(res.status, 302);
  assert.equal(res.headers.get("Location"), "https://github.com/s3lcsum");
  assert.equal(await res.text(), "");
});

test("GET /email allows mailto", async () => {
  const res = await hit("/email");
  assert.equal(res.status, 302);
  assert.equal(res.headers.get("Location"), "mailto:office@dominiksiejak.pl");
});

test("unknown path is 404", async () => {
  const res = await hit("/nope");
  assert.equal(res.status, 404);
});

test("POST is 405", async () => {
  const res = await hit("/github", { method: "POST" });
  assert.equal(res.status, 405);
});

test("javascript: destinations are blocked", async () => {
  const res = await hit("/evil");
  assert.equal(res.status, 502);
  assert.equal(res.headers.get("Location"), null);
});
