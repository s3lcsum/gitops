# Project MCP servers (Cursor)

Config: [`.cursor/mcp.json`](mcp.json) (copy from [`mcp.json.example`](mcp.json.example)).

| Server | Type | Docs |
|--------|------|------|
| `n8n-mcp` | stdio (`npx n8n-mcp`) | [czlonkowski/n8n-mcp](https://github.com/czlonkowski/n8n-mcp), [Cursor setup](https://github.com/czlonkowski/n8n-mcp/blob/main/docs/CURSOR_SETUP.md) |
| `grafana` | stdio (`uvx mcp-grafana`) | [Grafana MCP](https://grafana.com/docs/grafana/latest/ai-tools/mcp/) |
| `homeassistant` | HTTP | [HA MCP server](https://www.home-assistant.io/integrations/mcp_server/) → `https://hass.dominiksiejak.pl/api/mcp` |

## Secrets (shell env, not in git)

Export before starting Cursor (or add to your local shell profile):

- `N8N_API_KEY` — n8n **Settings → API** (requires `N8N_API_ENABLED=true` on the instance).
- `GRAFANA_SERVICE_ACCOUNT_TOKEN` — Grafana Cloud service account for `dreewniak.grafana.net` (also in OpenBao `secret/grafana`).

## Home Assistant OAuth

The HA entry uses the **Main URL** (`/api/mcp`). On first use, Cursor should run OAuth against Home Assistant (admin account if you expose all tools). Requires HA reachable at that URL (Cloudflare tunnel / WAN as you already use for Hass).

## Legacy file

Remove `.cursor/.mcp.json` if present — Cursor loads **`.cursor/mcp.json`** only.

After edits: **Settings → MCP** → restart servers or reload the window.
