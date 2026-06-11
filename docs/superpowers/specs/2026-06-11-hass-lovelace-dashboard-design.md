# HA Lovelace Dashboard Design

**Date:** 2026-06-11
**Scope:** Home Assistant — areas, entity assignments, mushroom-strategy dashboard with dense/informative layout

---

## 1. Areas

### Piętro
| Area name | Slug |
|---|---|
| Korytarz (piętro) | korytarz_pietro |
| Balkon | balkon |
| Pokój Jasia | pokoj_jasia |
| Pokój Dominika | pokoj_dominika |
| Pokój rodziców | pokoj_rodzicow |
| Łazienka (piętro) | lazienka_pietro |

### Parter
| Area name | Slug |
|---|---|
| Korytarz (parter) | korytarz_parter |
| Altana / wejście | altana_wejscie |
| Pokój Oliwii | pokoj_oliwii |
| Salon | salon |
| Kuchnia | kuchnia |

### Piwnica
| Area name | Slug |
|---|---|
| Toaleta | toaleta |
| Schowek | schowek_piwnica |
| Kotłownia | kotlownia |
| Pralnia | pralnia |
| Korytarz (piwnica) | korytarz_piwnica |

### Budynek drugi
| Area name | Slug |
|---|---|
| Warsztat (parter) | warsztat_parter |
| Schowek na narzędzia | schowek_narzedzia |
| Schowek na przedmioty | schowek_przedmioty |
| Warsztat (piętro) | warsztat_pietro |
| Schowek na kartony | schowek_kartony |
| Schowek na elektronikę i dokumenty | schowek_elektronika |

### Na zewnątrz
| Area name | Slug |
|---|---|
| Podjazd / od ulicy | podjazd |
| Parking / grill | parking_grill |
| Ogródek | ogrodek |

---

## 2. Entity → Area assignments

| Entity ID | Friendly name | Area |
|---|---|---|
| sensor.t_h_sensor_jas_temperature | T/H Sensor Jaś Temperature | Pokój Jasia |
| sensor.t_h_sensor_jas_humidity | T/H Sensor Jaś Humidity | Pokój Jasia |
| sensor.t_h_sensor_jas_battery | T/H Sensor Jaś Battery | Pokój Jasia |
| switch.bedroom_light_switch | Bedroom Light Switch | Pokój Jasia |
| sensor.t_h_sensor_dominik_temperature | T/H Sensor Dominik Temperature | Pokój Dominika |
| sensor.t_h_sensor_dominik_humidity | T/H Sensor Dominik Humidity | Pokój Dominika |
| sensor.t_h_sensor_dominik_battery | T/H Sensor Dominik Battery | Pokój Dominika |
| light.philips_hue_dominik | Philips Hue Dominik | Pokój Dominika |
| cover.toilet_curtain | Toilet Curtain | Toaleta |
| switch.switch_water_heater | Switch Water Heater | Kotłownia |
| sensor.switch_water_heater_power | Switch Water Heater Power | Kotłownia |
| sensor.switch_water_heater_energy | Switch Water Heater Energy | Kotłownia |
| switch.switch_washingmachine | Switch WashingMachine | Pralnia |
| sensor.switch_washingmachine_power | Switch WashingMachine Power | Pralnia |
| sensor.switch_washingmachine_energy | Switch WashingMachine Energy | Pralnia |

---

## 3. Dashboard

- **Title:** Dom
- **URL path:** `/dom`
- **Strategy:** `mushroom-strategy`
- mushroom-strategy auto-generates per-area views from the areas above

### 3.1 Manual views (pinned before auto-generated room views)

#### Dom (`mdi:home`)
- `mushroom-chips-card` — person chips: Dominik, Jan, Andrzej (home/away state) + weather chip
- `weather-forecast-card` — `weather.forecast_home`, show forecast
- `sun-position-card` — current sun position / horizon
- `mushroom-entity-card` — `switch.switch_water_heater` (quick toggle)
- `mushroom-entity-card` — `switch.switch_washingmachine` (quick toggle)

#### Klimat (`mdi:thermometer`)
For each sensor pair (Jaś, Dominik):
- `horizontal-stack`:
  - `mini-graph-card` — temperature, 24h history
  - `mini-graph-card` — humidity, 24h history
- `mushroom-entity-card` — current temp / humidity / battery state

#### Energia (`mdi:lightning-bolt`)
- `mini-graph-card` — `sensor.switch_water_heater_power` (wattage, 24h)
- `mini-graph-card` — `sensor.switch_washingmachine_power` (wattage, 24h)
- `mini-graph-card` — `sensor.switch_water_heater_energy` (cumulative kWh)
- `mini-graph-card` — `sensor.switch_washingmachine_energy` (cumulative kWh)
- `mushroom-entity-card` — switch state for both

#### Sieć (`mdi:network`)
- `mini-graph-card` — Cloudflare 10MB down + 25MB down (dual line, 24h)
- `mini-graph-card` — Cloudflare 10MB up (24h)
- `mushroom-entity-card` — latency (`sensor.cloudflare_speed_test_latency`) + jitter
- NAS section:
  - `mushroom-entity-card` — CPU total, load avg 5m/15m
  - `mushroom-entity-card` — RAM usage %, available real
  - `mushroom-entity-card` — Volume 1 used %, status
  - `mushroom-entity-card` — Drive 1 + Drive 2 temp + status
  - `mushroom-entity-card` — NAS temperature

#### Baterie (`mdi:battery`)
- `battery-state-card` covering:
  - `sensor.iphone_dom_battery_level`
  - `sensor.iphone_dom_watch_battery_level`
  - `sensor.iphone_dzony_battery_level`
  - `sensor.macbook_dominik_internal_battery_level`
  - `sensor.t_h_sensor_jas_battery`
  - `sensor.t_h_sensor_dominik_battery`

---

## 4. Out of scope

- Automations (existing ones untouched)
- YAML-mode dashboard config (all storage-mode via UI/MCP)
- Tasmota entities (currently all unavailable — skip until online)
- NAS reboot/shutdown buttons (admin-only, not surfaced in dashboard)
