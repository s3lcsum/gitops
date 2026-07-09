# Live Activities — Appliance Countdown (Washer / Dryer / Water Heater)

**Date:** 2026-07-09
**Status:** Design approved, ready to apply
**Target:** Home Assistant `s3lcsum/hass` config repo (automations + scripts YAML)

## Goal

When an appliance switch turns on, show a persistent Lock Screen / Dynamic Island /
notification-shade **countdown** (iOS Live Activity / Android Live Update) that ticks down
to the appliance's estimated end time. When the switch turns off, the activity clears.
Targeting reuses the existing "done notification" logic: only specific people, only when
home.

## Prerequisites

- [x] **HA Core 2026.7.0+** — user confirmed already upgraded (was `2026.6.2`).
- [x] **iOS**: TestFlight companion app, iOS 17.2+. **Android**: 16+. (User confirmed both.)
- [ ] **Apply path**: MCP server currently down (read-only `logs` on server). Config repo
      `s3lcsum/hass` not checked out locally. Needs MCP up OR repo checkout to apply.

## Approach

**B — one reusable script + 3 thin trigger automations.**

- `script.live_activity_start` computes the countdown `when` from an ETA entity and sends
  the `live_update` start.
- 3 thin automations (washer / dryer / water heater), each:
  - trigger `switch` → `on` → call `script.live_activity_start`
  - trigger `switch` → `off` → send `clear_notification` for that tag
- The **existing done-notification script is untouched** — it already notifies the right
  home people on completion. The Live Activity is purely the countdown; it only clears on
  switch-off. The `live_update` send reuses the **same home-occupant notify target** the
  existing script uses.

## Why chronometer only (no progress bar)

The visible countdown is driven by `chronometer` + `when` (seconds from now). It ticks
on-device, so we push **once** at start and **once** at clear — zero per-second traffic,
no iOS throttling. A `progress`/`progress_max` bar would be static (we don't push mid-cycle)
and misleading, so it is omitted.

## `script.live_activity_start`

```yaml
script:
  live_activity_start:
    alias: "Live Activity — Start (Appliance Countdown)"
    description: >-
      Starts an iOS Live Activity / Android Live Update countdown derived from an
      ETA entity (minutes-remaining or end-datetime).
    fields:
      tag:
        name: Tag
        description: Unique activity id (letters, numbers, - _)
        required: true
      title:
        name: Title
        description: Static header shown on the Lock Screen
        required: true
      icon:
        name: Icon
        description: Material Design Icon slug, e.g. mdi:washing-machine
        required: true
      color:
        name: Color
        description: Hex tint for icon + progress, e.g. "#2196F3"
        required: true
      eta_entity:
        name: ETA entity
        description: Entity id of the remaining-time / end-time source
        required: true
      eta_format:
        name: ETA format
        description: "minutes" (number = minutes left) or "datetime" (end timestamp)
        required: true
    sequence:
      - variables:
          remaining: >-
            {% if eta_format == 'datetime' %}
              {{ [ (as_timestamp(states(eta_entity)) - as_timestamp(now())) | int(0), 60 ] | max }}
            {% else %}
              {{ [ (states(eta_entity) | float(0) * 60) | int(0), 60 ] | max }}
            {% endif %}
      - action: notify.home_occupants   # PLACEHOLDER: existing home-occupant target (must resolve to notify.mobile_app_* device(s))
        data:
          title: "{{ title }}"
          message: "{{ title }} — w toku"
          data:
            tag: "{{ tag }}"
            live_update: true
            chronometer: true
            when: "{{ remaining }}"
            when_relative: true
            notification_icon: "{{ icon }}"
            notification_icon_color: "{{ color }}"
            color: "{{ color }}"
```

Note: `input_datetime` state must include a date for `as_timestamp` to parse reliably.
If `input_datetime.water_heater_off_time` is time-only, wrap:
`as_timestamp(states(eta_entity), now().date() ~ ' ')`.

## 3 thin automations

```yaml
automation:
  # ---------- Washer ----------
  - id: live_activity_washer
    alias: "Live Activity — Pralka"
    description: "Washer countdown Live Activity."
    mode: single
    labels:
      - Poziom 2
    triggers:
      - trigger: state
        entity_id: switch.pralka          # PLACEHOLDER: confirm washer switch id
        to: "on"
        id: start
      - trigger: state
        entity_id: switch.pralka          # PLACEHOLDER: confirm washer switch id
        to: "off"
        id: stop
    actions:
      - choose:
          - conditions:
              - condition: template
                value_template: "{{ trigger.id == 'start' }}"
            sequence:
              - action: script.live_activity_start
                data:
                  tag: washer
                  title: Pralka
                  icon: mdi:washing-machine
                  color: "#2196F3"
                  eta_entity: sensor.washer_remaining_time
                  eta_format: minutes
          - conditions:
              - condition: template
                value_template: "{{ trigger.id == 'stop' }}"
            sequence:
              - action: notify.home_occupants   # PLACEHOLDER: same home-occupant target
                data:
                  message: clear_notification
                  data:
                    tag: washer

  # ---------- Dryer (suszarka) ----------
  - id: live_activity_dryer
    alias: "Live Activity — Suszarka"
    description: "Dryer countdown Live Activity."
    mode: single
    labels:
      - Poziom 2
    triggers:
      - trigger: state
        entity_id: switch.pralnia_suszarka   # PLACEHOLDER: confirm dryer switch id
        to: "on"
        id: start
      - trigger: state
        entity_id: switch.pralnia_suszarka   # PLACEHOLDER: confirm dryer switch id
        to: "off"
        id: stop
    actions:
      - choose:
          - conditions:
              - condition: template
                value_template: "{{ trigger.id == 'start' }}"
            sequence:
              - action: script.live_activity_start
                data:
                  tag: dryer
                  title: Suszarka
                  icon: mdi:tumble-dryer
                  color: "#FF9800"
                  eta_entity: sensor.pralnia_suszarka_remaining_time
                  eta_format: minutes
          - conditions:
              - condition: template
                value_template: "{{ trigger.id == 'stop' }}"
            sequence:
              - action: notify.home_occupants   # PLACEHOLDER: same home-occupant target
                data:
                  message: clear_notification
                  data:
                    tag: dryer

  # ---------- Water heater (podgrzewacz) ----------
  - id: live_activity_water_heater
    alias: "Live Activity — Podgrzewacz Wody"
    description: "Water heater countdown Live Activity."
    mode: single
    labels:
      - Poziom 2
    triggers:
      - trigger: state
        entity_id: switch.podgrzewacz_wody
        to: "on"
        id: start
      - trigger: state
        entity_id: switch.podgrzewacz_wody
        to: "off"
        id: stop
    actions:
      - choose:
          - conditions:
              - condition: template
                value_template: "{{ trigger.id == 'start' }}"
            sequence:
              - action: script.live_activity_start
                data:
                  tag: water_heater
                  title: Podgrzewacz Wody
                  icon: mdi:water-boiler
                  color: "#00BCD4"
                  eta_entity: input_datetime.water_heater_off_time
                  eta_format: datetime
          - conditions:
              - condition: template
                value_template: "{{ trigger.id == 'stop' }}"
            sequence:
              - action: notify.home_occupants   # PLACEHOLDER: same home-occupant target
                data:
                  message: clear_notification
                  data:
                    tag: water_heater
```

## Entity map

| Appliance | Switch (trigger) | ETA entity | ETA fmt | tag | Icon | Color |
|---|---|---|---|---|---|---|
| Washer | `switch.pralka` **(placeholder)** | `sensor.washer_remaining_time` | minutes | `washer` | `mdi:washing-machine` | `#2196F3` |
| Dryer | `switch.pralnia_suszarka` **(placeholder)** | `sensor.pralnia_suszarka_remaining_time` | minutes | `dryer` | `mdi:tumble-dryer` | `#FF9800` |
| Water heater | `switch.podgrzewacz_wody` | `input_datetime.water_heater_off_time` | datetime | `water_heater` | `mdi:water-boiler` | `#00BCD4` |

`notify.home_occupants` — **placeholder** for the existing home-occupant target the current
done-notification script uses. Must resolve to `notify.mobile_app_*` device(s) for Live
Activities to work.

## Open items (confirm before apply)

1. Exact washer switch entity id (placeholder `switch.pralka`).
2. Exact dryer switch entity id (placeholder `switch.pralnia_suszarka`).
3. Exact home-occupant notify target (placeholder `notify.home_occupants`) — confirm it
   resolves to `notify.mobile_app_*` device(s) and mirrors the existing presence gating.

## Verification

1. Turn washer switch on → Live Activity appears, counts down to `sensor.washer_remaining_time`.
2. Turn it off → existing done-notification fires + Live Activity clears.
3. Repeat for dryer and water heater (water heater counts down to `input_datetime.water_heater_off_time`).
4. Confirm only home occupants receive it (reused targeting).
5. Confirm no update spam: exactly 1 push at start, 1 clear at end (chronometer ticks on-device).
