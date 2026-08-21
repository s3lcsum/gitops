# Design: HA → Messenger notifications via psid-based custom notify platform

Date: 2026-08-21
Status: Approved

## Problem

Home Assistant's native `notify.facebook` platform is a legacy integration that
hardcodes `messaging_type: MESSAGE_TAG` with `tag: HUMAN_AGENT` in its
`send_message` implementation. Meta requires prior approval for the `HUMAN_AGENT`
tag, so every send through it fails with `Error 400 (#100) Cannot tag messages
with 'HUMAN_AGENT' without prior approval`.

Attempting to fix via phone number is not viable either: the `send-api phone_number`
path requires the advanced `pages_messaging_phone_number` permission (Meta business
verification + App Review) and the legacy `Customer Matching` flow.

However, direct Graph API calls to `me/messages` with a **page-scoped user ID (PSID)**
as `recipient.id`, `messaging_type: RESPONSE`, and no tag **work immediately** with a
standard page access token — no extra permission, no App Review, no business
verification. This is the standard Messenger messaging model where the recipient has
already started a conversation with the Page.

## Goal

Route the existing HA notification scripts (`script.notify_person`,
`script.notify_people_home`) for Dominik, Jan, and Danuta through Messenger instead
of the mobile-app device notifiers, using the working PSID + `RESPONSE` send.

## Architecture

A minimal HA custom notify platform that wraps the working Graph API call, exposed
as standard `notify.<name>` entities that scripts/automations already know how to
target.

### Component: custom_components/notify_psid

- `custom_components/notify_psid/__init__.py` — platform discovery (empty, notify
  integration handles loading).
- `custom_components/notify_psid/notify.py` — `Notifier` class implementing
  `BaseNotificationService`:
  - `send_message(message, **kwargs)` POSTs to
    `https://graph.facebook.com/v19.0/me/messages?access_token=<token>` with JSON body:
    ```json
    {
      "recipient": { "id": "<psid>" },
      "message": { "text": "<message>" },
      "messaging_type": "RESPONSE"
    }
    ```
  - Logs a clear error (like the built-in platform) if the response is not HTTP 200.
  - `title` from data is ignored (iOS-specific; Messenger has no title concept).

### Config (configuration.yaml)

Three notifier instances, one per family member PSID:

```yaml
notify:
  - platform: notify_psid
    name: messenger_dominik
    psid: "28826229860312894"
    access_token: !secret facebook_page_access_token
  - platform: notify_psid
    name: messenger_jan
    psid: "27948189831503096"
    access_token: !secret facebook_page_access_token
  - platform: notify_psid
    name: messenger_dantua
    psid: "27914858414802372"
    access_token: !secret facebook_page_access_token
```

Note: `psid` and `access_token` are treated as strings (PSIDs are 64-bit and can
exceed JS number precision; the token has characters that YAML may parse oddly).

Creates entities: `notify.messenger_dominik`, `notify.messenger_jan`,
`notify.messenger_dantua`.

## Script changes

### script.notify_person

Replace the `notify_map` variables:

- `person.dominik` → `[notify.messenger_dominik]`
- `person.jan` → `[notify.messenger_jan]` (Jan's previous `notify.iphone_dzony`
  targets an entity that no longer exists — this also fixes a dead branch)
- `person.dantua` → `[notify.messenger_dantua]`

Targets are still processed with `notify.send_message` (generic), so no other change.

### script.notify_people_home

- Dominik branch: `notify.iphone_dominik` + `notify.macbook_dominik` →
  `notify.messenger_dominik`
- Jan branch: `notify.iphone_dzony` → `notify.messenger_jan`
- Dantua branch: `notify.samsung_danka` → `notify.messenger_dantua`
- Oliwia branch unchanged (mobile app, no PSID yet)

The iOS-only `title` field is dropped on Messenger sends; only `message` is used.

## Files touched

- `custom_components/notify_psid/__init__.py` (new)
- `custom_components/notify_psid/notify.py` (new)
- `configuration.yaml` (notify block)
- `scripts.yaml` (`notify_person`, `notify_people_home`)
- `.storage/` (auto-updated at runtime by HA)

For the hass repo: `github.com/s3lcsum/hass` mirrored to Gitea `dominiksiejak/hass`.

## Testing

1. Restart HA (or reload notify) to load the new platform.
2. `ha_get_state` on `notify.messenger_dominik` to confirm entity registered.
3. Run `script.notify_person` with `person=person.dominik`, a test message.
4. Confirm no error in HA log and message delivered in Messenger for Dominik.
5. Repeat verification for Jan / Danuta after their PSIDs are wired.

## Deferred

- A single `notify.messenger` that maps `person → PSID` for all family members.
- Optionally set a `person → PSID` registry so people not yet in a Page
  conversation can be added later.
- Oliwia PSID and other family members once they message the Page.
