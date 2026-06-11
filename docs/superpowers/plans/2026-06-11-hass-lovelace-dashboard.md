# HA Lovelace Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 24 HA areas, assign existing entities to the correct rooms, and build a dense mushroom-strategy dashboard with 5 manual views (Dom, Klimat, Energia, Sieć, Baterie).

**Architecture:** Areas and entity assignments go through the HA WebSocket API via Playwright (no dedicated MCP area tool exists). The dashboard is created via `mcp__homeassistant__ha_config_set_dashboard` using `custom:mushroom-strategy` as the top-level strategy and hand-crafted views for the 5 manual sections. HACS cards (mushroom, mini-graph-card, battery-state-card, weather-forecast-card, sun-position-card) are already installed.

**Tech Stack:** Home Assistant MCP tools, Playwright (WebSocket API calls), mushroom-strategy, mini-graph-card, battery-state-card, weather-forecast-card, sun-position-card

---

## Task 1: Create all 24 areas via WebSocket API

Areas must be created before entity assignments. Use Playwright to call the HA WebSocket API at `ws://hass.lake.dominiksiejak.pl/api/websocket`.

**Files:** none (HA state change only)

- [ ] **Step 1: Open HA WebSocket connection and authenticate**

Navigate to `http://hass.lake.dominiksiejak.pl` in Playwright, open the browser console, and run:

```javascript
// Get the long-lived access token from HA settings first
// Settings → Profile → Long-Lived Access Tokens → Create token
// Then paste it below
const TOKEN = "YOUR_TOKEN_HERE";
const ws = new WebSocket("ws://hass.lake.dominiksiejak.pl/api/websocket");
let msgId = 1;
ws.onmessage = (e) => console.log("IN:", e.data);
ws.onopen = () => {
  ws.send(JSON.stringify({ type: "auth", access_token: TOKEN }));
};
```

Expected: `{"type":"auth_ok","ha_version":"..."}`

> **Alternative (no token needed):** Log in to HA UI at `http://hass.lake.dominiksiejak.pl`, then use the MCP tool `mcp__homeassistant__ha_call_service` — but area creation is NOT available as a service. Use the Playwright approach below.

- [ ] **Step 2: Create Piętro floor areas (6 areas)**

In the Playwright browser console (authenticated session from Step 1):

```javascript
const areas = [
  "Korytarz (piętro)",
  "Balkon",
  "Pokój Jasia",
  "Pokój Dominika",
  "Pokój rodziców",
  "Łazienka (piętro)",
];
areas.forEach((name) => {
  ws.send(JSON.stringify({ id: msgId++, type: "config/area_registry/create", name }));
});
```

Expected: 6 responses each with `"type":"result","success":true` and an `area_id` field. Note down the `area_id` values — you'll need them for Task 2.

- [ ] **Step 3: Create Parter floor areas (5 areas)**

```javascript
const areas = [
  "Korytarz (parter)",
  "Altana / wejście",
  "Pokój Oliwii",
  "Salon",
  "Kuchnia",
];
areas.forEach((name) => {
  ws.send(JSON.stringify({ id: msgId++, type: "config/area_registry/create", name }));
});
```

Expected: 5 responses with `"success":true`.

- [ ] **Step 4: Create Piwnica areas (5 areas)**

```javascript
const areas = [
  "Toaleta",
  "Schowek",
  "Kotłownia",
  "Pralnia",
  "Korytarz (piwnica)",
];
areas.forEach((name) => {
  ws.send(JSON.stringify({ id: msgId++, type: "config/area_registry/create", name }));
});
```

Expected: 5 responses with `"success":true`.

- [ ] **Step 5: Create Budynek drugi areas (6 areas)**

```javascript
const areas = [
  "Warsztat (parter)",
  "Schowek na narzędzia",
  "Schowek na przedmioty",
  "Warsztat (piętro)",
  "Schowek na kartony",
  "Schowek na elektronikę i dokumenty",
];
areas.forEach((name) => {
  ws.send(JSON.stringify({ id: msgId++, type: "config/area_registry/create", name }));
});
```

Expected: 6 responses with `"success":true`.

- [ ] **Step 6: Create Na zewnątrz areas (3 areas)**

```javascript
const areas = [
  "Podjazd / od ulicy",
  "Parking / grill",
  "Ogródek",
];
areas.forEach((name) => {
  ws.send(JSON.stringify({ id: msgId++, type: "config/area_registry/create", name }));
});
```

Expected: 3 responses with `"success":true`.

- [ ] **Step 7: Verify all 24 areas exist**

```javascript
ws.send(JSON.stringify({ id: msgId++, type: "config/area_registry/list" }));
```

Expected: response with 24 area objects. Count them.

- [ ] **Step 8: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): create 24 areas in HA area registry"
```

---

## Task 2: Assign entities to areas via WebSocket API

Requires the `area_id` values noted from Task 1. First list the device registry to get `device_id` for each device — entity area assignment goes through the device, not the entity directly (unless the entity has no device, in which case use entity registry).

**Files:** none (HA state change only)

- [ ] **Step 1: List all devices to get device_id values**

```javascript
ws.send(JSON.stringify({ id: msgId++, type: "config/device_registry/list" }));
```

From the response, find `device_id` for:
- T/H Sensor Jaś
- T/H Sensor Dominik
- Bedroom Light Switch
- Philips Hue Dominik
- Toilet Curtain
- Switch Water Heater
- Switch WashingMachine

- [ ] **Step 2: List area registry to get area_id values**

```javascript
ws.send(JSON.stringify({ id: msgId++, type: "config/area_registry/list" }));
```

Map these names to their `area_id`:
| Name | area_id |
|---|---|
| Pokój Jasia | (from response) |
| Pokój Dominika | (from response) |
| Toaleta | (from response) |
| Kotłownia | (from response) |
| Pralnia | (from response) |

- [ ] **Step 3: Assign devices to areas**

Replace each `DEVICE_ID_*` and `AREA_ID_*` with the values from Steps 1 and 2:

```javascript
const assignments = [
  { device_id: "DEVICE_ID_TH_JAS",        area_id: "AREA_ID_POKOJ_JASIA" },
  { device_id: "DEVICE_ID_BEDROOM_SWITCH", area_id: "AREA_ID_POKOJ_JASIA" },
  { device_id: "DEVICE_ID_TH_DOMINIK",    area_id: "AREA_ID_POKOJ_DOMINIKA" },
  { device_id: "DEVICE_ID_HUE_DOMINIK",   area_id: "AREA_ID_POKOJ_DOMINIKA" },
  { device_id: "DEVICE_ID_CURTAIN",       area_id: "AREA_ID_TOALETA" },
  { device_id: "DEVICE_ID_WATER_HEATER",  area_id: "AREA_ID_KOTLOWNIA" },
  { device_id: "DEVICE_ID_WASHINGMACHINE",area_id: "AREA_ID_PRALNIA" },
];
assignments.forEach(({ device_id, area_id }) => {
  ws.send(JSON.stringify({ id: msgId++, type: "config/device_registry/update", device_id, area_id }));
});
```

Expected: 7 responses with `"success":true`.

- [ ] **Step 4: Verify assignments**

```javascript
ws.send(JSON.stringify({ id: msgId++, type: "config/device_registry/list" }));
```

Check that each device now shows the correct `area_id`.

- [ ] **Step 5: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): assign entities to areas"
```

---

## Task 3: Create the mushroom-strategy dashboard skeleton

Creates the dashboard with the mushroom-strategy and the 5 manual views. Card content is added in Tasks 4–8.

**Files:** none (HA state change only)

- [ ] **Step 1: Create dashboard with mushroom-strategy and all 5 views**

Call `mcp__homeassistant__ha_config_set_dashboard` with:

```json
{
  "url_path": "dom-glowny",
  "title": "Dom",
  "icon": "mdi:home",
  "show_in_sidebar": true,
  "config": {
    "strategy": {
      "type": "custom:mushroom-strategy",
      "options": {
        "quick_access_cards": [],
        "extra_views": []
      }
    },
    "views": [
      {
        "title": "Dom",
        "path": "dom",
        "icon": "mdi:home",
        "type": "sections",
        "max_columns": 3,
        "sections": []
      },
      {
        "title": "Klimat",
        "path": "klimat",
        "icon": "mdi:thermometer",
        "type": "sections",
        "max_columns": 2,
        "sections": []
      },
      {
        "title": "Energia",
        "path": "energia",
        "icon": "mdi:lightning-bolt",
        "type": "sections",
        "max_columns": 2,
        "sections": []
      },
      {
        "title": "Sieć",
        "path": "siec",
        "icon": "mdi:network",
        "type": "sections",
        "max_columns": 2,
        "sections": []
      },
      {
        "title": "Baterie",
        "path": "baterie",
        "icon": "mdi:battery",
        "type": "sections",
        "max_columns": 2,
        "sections": []
      }
    ]
  }
}
```

- [ ] **Step 2: Verify dashboard was created**

Call `mcp__homeassistant__ha_config_list_dashboards` and confirm `dom-glowny` appears with 5 views.

Open `http://hass.lake.dominiksiejak.pl/dom-glowny` in browser and confirm the sidebar shows "Dom" and the 5 tabs are visible.

- [ ] **Step 3: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): create Dom dashboard skeleton with mushroom-strategy"
```

---

## Task 4: Populate Dom view

**Files:** none (HA state change only)

- [ ] **Step 1: Update Dom view with cards**

Call `mcp__homeassistant__ha_config_set_dashboard` targeting the existing `dom-glowny` dashboard. Retrieve its `dashboard_id` first from `ha_config_list_dashboards`, then update only the Dom view sections:

```json
{
  "title": "Dom",
  "path": "dom",
  "icon": "mdi:home",
  "type": "sections",
  "max_columns": 3,
  "sections": [
    {
      "title": "Obecność",
      "cards": [
        {
          "type": "grid",
          "columns": 3,
          "square": false,
          "cards": [
            {
              "type": "custom:mushroom-person-card",
              "entity": "person.dominik",
              "name": "Dominik",
              "tap_action": { "action": "more-info" }
            },
            {
              "type": "custom:mushroom-person-card",
              "entity": "person.jan",
              "name": "Jan",
              "tap_action": { "action": "more-info" }
            },
            {
              "type": "custom:mushroom-person-card",
              "entity": "person.andrzej",
              "name": "Andrzej",
              "tap_action": { "action": "more-info" }
            }
          ]
        }
      ]
    },
    {
      "title": "Pogoda",
      "cards": [
        {
          "type": "weather-forecast",
          "entity": "weather.forecast_home",
          "forecast_type": "daily",
          "show_forecast": true
        },
        {
          "type": "custom:sun-position-card",
          "name": "Słońce"
        }
      ]
    },
    {
      "title": "Urządzenia",
      "cards": [
        {
          "type": "grid",
          "columns": 2,
          "square": false,
          "cards": [
            {
              "type": "tile",
              "entity": "switch.switch_water_heater",
              "name": "Bojler",
              "icon": "mdi:water-boiler",
              "features": [{ "type": "toggle" }]
            },
            {
              "type": "tile",
              "entity": "switch.switch_washingmachine",
              "name": "Pralka",
              "icon": "mdi:washing-machine",
              "features": [{ "type": "toggle" }]
            }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify in browser**

Open `http://hass.lake.dominiksiejak.pl/dom-glowny/dom`. Confirm:
- 3 person chips visible with home/away state
- Weather forecast card renders
- Sun position card renders
- 2 switch tiles visible and toggleable

- [ ] **Step 3: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): populate Dom view with presence, weather, device cards"
```

---

## Task 5: Populate Klimat view

**Files:** none (HA state change only)

- [ ] **Step 1: Update Klimat view with mini-graph-cards**

```json
{
  "title": "Klimat",
  "path": "klimat",
  "icon": "mdi:thermometer",
  "type": "sections",
  "max_columns": 2,
  "sections": [
    {
      "title": "Pokój Jasia",
      "cards": [
        {
          "type": "custom:mini-graph-card",
          "name": "Temperatura – Jaś",
          "entities": [{ "entity": "sensor.t_h_sensor_jas_temperature" }],
          "hours_to_show": 24,
          "points_per_hour": 4,
          "line_width": 2,
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "custom:mini-graph-card",
          "name": "Wilgotność – Jaś",
          "entities": [{ "entity": "sensor.t_h_sensor_jas_humidity" }],
          "hours_to_show": 24,
          "points_per_hour": 4,
          "line_width": 2,
          "color": "#44739e",
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "grid",
          "columns": 2,
          "square": false,
          "cards": [
            {
              "type": "tile",
              "entity": "sensor.t_h_sensor_jas_temperature",
              "name": "Temp"
            },
            {
              "type": "tile",
              "entity": "sensor.t_h_sensor_jas_humidity",
              "name": "Wilgotność"
            }
          ]
        }
      ]
    },
    {
      "title": "Pokój Dominika",
      "cards": [
        {
          "type": "custom:mini-graph-card",
          "name": "Temperatura – Dominik",
          "entities": [{ "entity": "sensor.t_h_sensor_dominik_temperature" }],
          "hours_to_show": 24,
          "points_per_hour": 4,
          "line_width": 2,
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "custom:mini-graph-card",
          "name": "Wilgotność – Dominik",
          "entities": [{ "entity": "sensor.t_h_sensor_dominik_humidity" }],
          "hours_to_show": 24,
          "points_per_hour": 4,
          "line_width": 2,
          "color": "#44739e",
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "grid",
          "columns": 2,
          "square": false,
          "cards": [
            {
              "type": "tile",
              "entity": "sensor.t_h_sensor_dominik_temperature",
              "name": "Temp"
            },
            {
              "type": "tile",
              "entity": "sensor.t_h_sensor_dominik_humidity",
              "name": "Wilgotność"
            }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify in browser**

Open `http://hass.lake.dominiksiejak.pl/dom-glowny/klimat`. Confirm:
- 2 sections: Pokój Jasia and Pokój Dominika
- Each section has a temperature graph, humidity graph, and current value tiles
- Graphs show 24h history (may be flat if sensors are new)

- [ ] **Step 3: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): populate Klimat view with mini-graph-cards"
```

---

## Task 6: Populate Energia view

**Files:** none (HA state change only)

- [ ] **Step 1: Update Energia view**

```json
{
  "title": "Energia",
  "path": "energia",
  "icon": "mdi:lightning-bolt",
  "type": "sections",
  "max_columns": 2,
  "sections": [
    {
      "title": "Bojler",
      "cards": [
        {
          "type": "custom:mini-graph-card",
          "name": "Moc – Bojler",
          "entities": [{ "entity": "sensor.switch_water_heater_power" }],
          "hours_to_show": 24,
          "points_per_hour": 4,
          "line_width": 2,
          "unit": "W",
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "custom:mini-graph-card",
          "name": "Zużycie energii – Bojler",
          "entities": [{ "entity": "sensor.switch_water_heater_energy" }],
          "hours_to_show": 24,
          "points_per_hour": 1,
          "line_width": 2,
          "unit": "kWh",
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "tile",
          "entity": "switch.switch_water_heater",
          "name": "Bojler",
          "icon": "mdi:water-boiler",
          "features": [{ "type": "toggle" }]
        }
      ]
    },
    {
      "title": "Pralka",
      "cards": [
        {
          "type": "custom:mini-graph-card",
          "name": "Moc – Pralka",
          "entities": [{ "entity": "sensor.switch_washingmachine_power" }],
          "hours_to_show": 24,
          "points_per_hour": 4,
          "line_width": 2,
          "unit": "W",
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "custom:mini-graph-card",
          "name": "Zużycie energii – Pralka",
          "entities": [{ "entity": "sensor.switch_washingmachine_energy" }],
          "hours_to_show": 24,
          "points_per_hour": 1,
          "line_width": 2,
          "unit": "kWh",
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "tile",
          "entity": "switch.switch_washingmachine",
          "name": "Pralka",
          "icon": "mdi:washing-machine",
          "features": [{ "type": "toggle" }]
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify in browser**

Open `http://hass.lake.dominiksiejak.pl/dom-glowny/energia`. Confirm:
- 2 sections: Bojler and Pralka
- Each has power graph (W), energy graph (kWh), and a switch tile

- [ ] **Step 3: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): populate Energia view with power and energy graphs"
```

---

## Task 7: Populate Sieć view

**Files:** none (HA state change only)

- [ ] **Step 1: Update Sieć view**

```json
{
  "title": "Sieć",
  "path": "siec",
  "icon": "mdi:network",
  "type": "sections",
  "max_columns": 2,
  "sections": [
    {
      "title": "Internet",
      "cards": [
        {
          "type": "custom:mini-graph-card",
          "name": "Pobieranie",
          "entities": [
            { "entity": "sensor.cloudflare_speed_test_10mb_down", "name": "10MB" },
            { "entity": "sensor.cloudflare_speed_test_25mb_down", "name": "25MB" }
          ],
          "hours_to_show": 24,
          "points_per_hour": 1,
          "line_width": 2,
          "unit": "Mbps",
          "show": { "labels": true, "points": false, "legend": true }
        },
        {
          "type": "custom:mini-graph-card",
          "name": "Wysyłanie",
          "entities": [
            { "entity": "sensor.cloudflare_speed_test_10mb_up", "name": "10MB" }
          ],
          "hours_to_show": 24,
          "points_per_hour": 1,
          "line_width": 2,
          "unit": "Mbps",
          "show": { "labels": true, "points": false, "legend": false }
        },
        {
          "type": "grid",
          "columns": 2,
          "square": false,
          "cards": [
            {
              "type": "tile",
              "entity": "sensor.cloudflare_speed_test_latency",
              "name": "Latencja"
            },
            {
              "type": "tile",
              "entity": "sensor.cloudflare_speed_test_jitter",
              "name": "Jitter"
            }
          ]
        }
      ]
    },
    {
      "title": "NAS",
      "cards": [
        {
          "type": "grid",
          "columns": 2,
          "square": false,
          "cards": [
            {
              "type": "tile",
              "entity": "sensor.nas_cpu_utilization_total",
              "name": "CPU"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_memory_usage_real",
              "name": "RAM"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_cpu_load_average_5_min",
              "name": "Load 5m"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_cpu_load_average_15_min",
              "name": "Load 15m"
            }
          ]
        },
        {
          "type": "grid",
          "columns": 3,
          "square": false,
          "cards": [
            {
              "type": "tile",
              "entity": "sensor.nas_volume_1_volume_used",
              "name": "Dysk użyty"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_volume_1_status",
              "name": "Status wolumenu"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_temperature",
              "name": "Temp NAS"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_drive_1_temperature",
              "name": "Temp Dysk 1"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_drive_2_temperature",
              "name": "Temp Dysk 2"
            },
            {
              "type": "tile",
              "entity": "sensor.nas_drive_1_status",
              "name": "Status Dysk 1"
            }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify in browser**

Open `http://hass.lake.dominiksiejak.pl/dom-glowny/siec`. Confirm:
- Download/upload speed graphs render with multiple lines
- Latency and jitter tiles visible
- NAS section shows CPU, RAM, disk temps

- [ ] **Step 3: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): populate Sieć view with internet and NAS monitoring"
```

---

## Task 8: Populate Baterie view

**Files:** none (HA state change only)

- [ ] **Step 1: Update Baterie view**

```json
{
  "title": "Baterie",
  "path": "baterie",
  "icon": "mdi:battery",
  "type": "sections",
  "max_columns": 1,
  "sections": [
    {
      "title": "Stan baterii",
      "cards": [
        {
          "type": "custom:battery-state-card",
          "title": "Baterie",
          "sort_by_level": "asc",
          "entities": [
            {
              "entity": "sensor.iphone_dom_battery_level",
              "name": "iPhone Dominik",
              "charging_state": {
                "entity_id": "sensor.iphone_dom_battery_state",
                "charging_state": "Charging"
              }
            },
            {
              "entity": "sensor.iphone_dom_watch_battery_level",
              "name": "Apple Watch Dominik",
              "charging_state": {
                "entity_id": "sensor.iphone_dom_watch_battery_state",
                "charging_state": "Charging"
              }
            },
            {
              "entity": "sensor.iphone_dzony_battery_level",
              "name": "iPhone Jaś",
              "charging_state": {
                "entity_id": "sensor.iphone_dzony_battery_state",
                "charging_state": "Charging"
              }
            },
            {
              "entity": "sensor.macbook_dominik_internal_battery_level",
              "name": "MacBook Dominik",
              "charging_state": {
                "entity_id": "sensor.macbook_dominik_internal_battery_state",
                "charging_state": "Charging"
              }
            },
            {
              "entity": "sensor.t_h_sensor_jas_battery",
              "name": "T/H Sensor – Jaś"
            },
            {
              "entity": "sensor.t_h_sensor_dominik_battery",
              "name": "T/H Sensor – Dominik"
            }
          ]
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify in browser**

Open `http://hass.lake.dominiksiejak.pl/dom-glowny/baterie`. Confirm:
- battery-state-card renders with 6 entries
- Bars sorted from lowest to highest charge
- Charging indicators visible where applicable

- [ ] **Step 3: Commit**

```bash
git -C /Users/dsiejak/Developer/s3lcsum/gitops commit --allow-empty -m "feat(hass): populate Baterie view with battery-state-card"
```

---

## Self-review checklist

- [x] All 24 areas from spec covered across Tasks 1 Steps 2–6
- [x] All 7 entity→area assignments covered in Task 2
- [x] mushroom-strategy dashboard skeleton in Task 3
- [x] Dom view (presence, weather, sun, switches) in Task 4
- [x] Klimat view (mini-graph-card temp+humidity per room) in Task 5
- [x] Energia view (power+energy graphs, switch tiles) in Task 6
- [x] Sieć view (speed test graphs, NAS monitoring) in Task 7
- [x] Baterie view (battery-state-card, 6 entities) in Task 8
- [x] No TBDs or placeholders — all entity IDs are exact from the overview
- [x] `weather-forecast-card` card type confirmed available in card types list
- [x] `battery-state-card` uses correct charging_state format per spec
- [x] Dashboard url_path contains hyphen (`dom-glowny`) — required by HA validation
