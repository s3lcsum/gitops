# HA → Messenger (psid notify) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route Dominik/Jan/Danuta notification scripts through Messenger via a new `notify_psid` custom notify platform that sends by PSID using `messaging_type: RESPONSE`.

**Architecture:** A minimal HA custom notify platform (`custom_components/notify_psid`) that POSTs to `graph.facebook.com/v19.0/me/messages` with `recipient.id=<PSID>` + `messaging_type: RESPONSE` (the call proven working). Three notifier instances configured in `configuration.yaml`. The existing `script.notify_person` / `script.notify_people_home` retarget their Dominik/Jan/Dantua branches to the new `notify.messenger_*` entities.

**Tech Stack:** Python HA custom component, HA notify platform API, Facebook Graph API v19.0, PyYAML.

## Global Constraints

- Files live on the live HA instance at Portainer: `/var/lib/hass/` (accessed via `ssh portainer -- docker exec hass ...` or directly via `ssh portainer -- 'cat /var/lib/hass/...'`). The `www/`, `.storage/`, `custom_components/`, `scripts.yaml`, `configuration.yaml` are there.
- The source-of-truth repo is `github.com/s3lcsum/hass` (mirrored to Gitea `dominiksiejak/hass`), NOT the gitops repo. Local `~/Developer/s3lcsum/hass` is not cloned — clone it if we want to track changes there. For the live test we edit the server directly.
- PSIDs must be treated as **strings** (64-bit ints exceed JS precision; YAML may parse digits as ints).
- Page access token is in `/var/lib/hass/secrets.yaml` under `facebook_page_access_token` — do NOT print/commit it.
- HA reload: config + script + notify changes need `homeassistant.reload_config_entry` or a full restart of the `hass` container (`docker restart hass`).
- Only Dominik/Jan/Danuta get Messenger; Oliwia stays on mobile app until her PSID exists.

---

### Task 1: Create the `notify_psid` custom notify platform

**Files:**
- Create: `/var/lib/hass/custom_components/notify_psid/__init__.py`
- Create: `/var/lib/hass/custom_components/notify_psid/notify.py`

**Interfaces:**
- Consumes: nothing (standalone).
- Produces: `notify_psid` notify platform; config schema keyed on `name`, `psid`, `access_token`; `Notifier.send_message(message, **kwargs)`.

- [ ] **Step 1: Create package `__init__.py`**

Write `/var/lib/hass/custom_components/notify_psid/__init__.py`:
```python
"""Custom notify platform that sends Facebook Messenger messages by PSID."""
```
(Notifier platform is discovered by the `notify` integration; no `async_setup_platform` needed at package level.)

- [ ] **Step 2: Create `notify.py`**

Write `/var/lib/hass/custom_components/notify_psid/notify.py`:
```python
"""Facebook Messenger notify platform sending to a page-scoped user ID (PSID)."""

from __future__ import annotations

import json
import logging
from http import HTTPStatus
from typing import Any

import requests
import voluptuous as vol

from homeassistant.components.notify import PLATFORM_SCHEMA, BaseNotificationService
from homeassistant.const import CONTENT_TYPE_JSON
from homeassistant.core import HomeAssistant
from homeassistant.helpers import config_validation as cv
from homeassistant.helpers.typing import ConfigType, DiscoveryInfoType

_LOGGER = logging.getLogger(__name__)

CONF_ACCESS_TOKEN = "access_token"
CONF_PSID = "psid"
BASE_URL = "https://graph.facebook.com/v19.0/me/messages"

PLATFORM_SCHEMA = PLATFORM_SCHEMA.extend(
    {
        vol.Required(CONF_ACCESS_TOKEN): cv.string,
        vol.Required(CONF_PSID): cv.string,
    }
)


def get_service(
    hass: HomeAssistant,
    config: ConfigType,
    discovery_info: DiscoveryInfoType | None = None,
) -> BaseNotificationService:
    """Get the Messenger notification service."""
    conf = config[CONF_ACCESS_TOKEN] if False else config  # keep schema access explicit
    return Notifier(conf[CONF_ACCESS_TOKEN], conf[CONF_PSID])


class Notifier(BaseNotificationService):
    """Notification service that sends Messenger messages to a fixed PSID."""

    def __init__(self, access_token: str, psid: str) -> None:
        """Initialize."""
        self._access_token = access_token
        self._psid = psid

    def send_message(self, message: str = "", **kwargs: Any) -> None:
        """Send a Messenger message."""
        payload = {"access_token": self._access_token}
        body = {
            "recipient": {"id": self._psid},
            "message": {"text": message},
            "messaging_type": "RESPONSE",
        }
        resp = requests.post(
            BASE_URL,
            data=json.dumps(body),
            params=payload,
            headers={"Content-Type": CONTENT_TYPE_JSON},
            timeout=10,
        )
        if resp.status_code != HTTPStatus.OK:
            obj = resp.json()
            err = obj.get("error", {})
            _LOGGER.error(
                "Messenger error %s : %s (Code %s)",
                resp.status_code,
                err.get("message"),
                err.get("code"),
            )
        else:
            _LOGGER.info(
                "Messenger message sent to PSID %s (message_id=%s)",
                self._psid,
                resp.json().get("message_id"),
            )
```

- [ ] **Step 3: Place files on the server and verify**

```bash
ssh portainer -- 'mkdir -p /var/lib/hass/custom_components/notify_psid'
# push both files; e.g. scp locally then cp into place, or heredoc via ssh
ssh portainer -- 'ls -la /var/lib/hass/custom_components/notify_psid/'
```
Expected: both files present, package dir created.

---

### Task 2: Configure three notifier instances

**Files:**
- Modify: `/var/lib/hass/configuration.yaml` (`notify:` block)

**Interfaces:**
- Consumes: `notify_psid` platform from Task 1.
- Produces: entities `notify.messenger_dominik`, `notify.messenger_jan`, `notify.messenger_dantua`.

- [ ] **Step 1: Edit the `notify:` block**

Current block:
```yaml
notify:
  - name: Facebook
    platform: facebook
    page_access_token: !secret facebook_page_access_token
```
Replace `platform: facebook` + keep it, and ADD the three PSID notifiers:
```yaml
notify:
  - name: Facebook
    platform: facebook
    page_access_token: !secret facebook_page_access_token
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
(Keeping the old `Facebook` notifier is harmless but note it is broken; suspend or remove it if you prefer. The spec keeps it.)

- [ ] **Step 2: Restart HA and verify entities**

```bash
ssh portainer -- 'docker restart hass'
```
Then query: `ha_get_state("notify.messenger_dominik")`
Expected: state present (`unknown` or last-sent timestamp). Also check jail log shows no config-load error:
```bash
ssh portainer -- 'grep -iE "notify_psid|messenger_dominik|Invalid config" /var/lib/hass/home-assistant.log | tail -20'
```

---

### Task 3: Retarget `script.notify_person`

**Files:**
- Modify: `/var/lib/hass/scripts.yaml` (`notify_person` `notify_map`)

**Interfaces:**
- Consumes: `notify.messenger_dominik`, `notify.messenger_jan`, `notify.messenger_dantua` from Task 2.
- Produces: a `notify_person` script that sends Messenger to Dominik/Jan/Dantua, mobile app to Oliwia.

- [ ] **Step 1: Edit `notify_map`**

In `notify_person`, the `variables.notify_map` becomes:
```yaml
      notify_map:
        person.dantua:
        - notify.messenger_dantua
        person.dominik:
        - notify.messenger_dominik
        person.jan:
        - notify.messenger_jan
        person.oliwia:
        - notify.iphone_oliwia
```
Note: the old `person.dominik` had `iphone_dominik` + `macbook_dominik`; now single Messenger target.

The `title` field is iOS-specific; the loop sends `data: message` and `title` — Messenger ignores `title`, keep as-is (harmless) OR drop. Keep for now.

- [ ] **Step 2: Reload scripts and verify config**

```bash
ssh portainer -- 'docker exec hass python3 -c "import yaml;yaml.safe_load(open(\"/config/scripts.yaml\"))" && echo YAML_OK'
ssh portainer -- 'docker restart hass'
```
Then check log for script parse errors.

---

### Task 4: Retarget `script.notify_people_home`

**Files:**
- Modify: `/var/lib/hass/scripts.yaml` (`notify_people_home`)

**Interfaces:**
- Consumes: `notify.messenger_dominik`, `notify.messenger_jan`, `notify.messenger_dantua` from Task 2.
- Produces: a `notify_people_home` script delivering per-person via Messenger.

- [ ] **Step 1: Edit the three branches**

In `notify_people_home`, change each branch's `target.entity_id`:
- Domink branch: `notify.iphone_dominik` + `notify.macbook_dominik` → `notify.messenger_dominik`
- Jan branch: `notify.iphone_dzony` → `notify.messenger_jan`
- Dantua branch: `notify.samsung_danka` → `notify.messenger_dantua`
- Oliwia branch: unchanged.

Drop `title` from the Messenger sends (keep only `message`).

- [ ] **Step 2: Reload and verify** (same as Task 3 Step 2)

---

### Task 5: End-to-end test for Dominik

**Files:** none (verification only).

- [ ] **Step 1: Run the script for Dominik**

```python
# via MCP
ha_call_service("script", "notify_person", data={"person": "person.dominik", "message": "Test Messenger notify_person ✅"})
```

- [ ] **Step 2: Confirm no error + delivery**

```bash
ssh portainer -- 'sleep 3; grep -iE "Messenger|notify_psid|ERROR" /var/lib/hass/home-assistant.log | tail -10'
```
Expected: an info line `Messenger message sent to PSID 28826229860312894` OR a clear error. Confirm message arrives in Dominik's Messenger.

- [ ] **Step 3: Repeat for Jan and Danuta** (optional, same pattern) and confirm eventual delivery.

---

## Self-Review Notes

- Spec coverage: notify_psid platform (T1), three instances (T2), notify_person (T3), notify_people_home (T4), e2e test (T5). All spec sections covered.
- No placeholders: every step has concrete file content and commands.
- Type consistency: `platform`, `name`, `psid`, `access_token` match across T1 schema, T2 config, and script targets.
