#!/usr/bin/env python3
"""Move secret/secrets/<slug> → secret/<slug>; delete secrets/ prefix."""
from __future__ import annotations

import json
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path

ADDR = 'https://bao.dominiksiejak.pl'


def read_file(path: Path) -> str:
    return path.read_text().strip()


def login(role_id: str, secret_id: str) -> str:
    body = json.dumps({'role_id': role_id, 'secret_id': secret_id}).encode()
    req = urllib.request.Request(
        f"{ADDR}/v1/auth/approle/login",
        data=body,
        method='POST',
        headers={'Content-Type': 'application/json'},
    )
    with urllib.request.urlopen(req, context=ssl.create_default_context()) as resp:
        return json.load(resp)['auth']['client_token']


def api(
    token: str,
    method: str,
    vault_path: str,
    body: dict | None = None,
) -> dict | None:
    url = f"{ADDR}/v1/{vault_path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            'X-Vault-Token': token,
            **({'Content-Type': 'application/json'} if data else {}),
        },
    )
    try:
        with urllib.request.urlopen(req, context=ssl.create_default_context()) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def list_keys(token: str, prefix: str) -> list[str]:
    out = api(token, 'GET', f"secret/metadata/{prefix}?list=true")
    if not out:
        return []
    return sorted(out.get('data', {}).get('keys', []))


def kv_get(token: str, logical: str) -> dict[str, str]:
    out = api(token, 'GET', f"secret/data/{logical}")
    if not out:
        return {}
    return dict(out.get('data', {}).get('data', {}))


def normalize_kv(data: dict) -> dict[str, str]:
    """Vault KV v2 + hashicorp/vault provider: every value must be a string."""
    out: dict[str, str] = {}
    for k, v in data.items():
        if k.startswith('__'):
            continue
        if isinstance(v, str):
            out[k] = v
        elif isinstance(v, (dict, list)):
            out[k] = json.dumps(v)
        elif isinstance(v, bool):
            out[k] = 'true' if v else 'false'
        elif isinstance(v, (int, float)):
            out[k] = str(v)
        else:
            out[k] = str(v)
    return out


def kv_put(token: str, logical: str, data: dict[str, str]) -> None:
    api(token, 'POST', f"secret/data/{logical}", {'data': normalize_kv(data)})


def kv_delete(token: str, logical: str) -> None:
    api(token, 'DELETE', f"secret/metadata/{logical}")


def main() -> int:
    cfg = Path.home() / '.config/openbao'
    token = login(read_file(cfg / 'role_id'), read_file(cfg / 'secret_id'))

    slugs = list_keys(token, 'secrets')
    if not slugs:
        print('no secrets/* keys (already flat?)', file=sys.stderr)
        return 0

    for slug in slugs:
        slug = slug.rstrip('/')
        data = kv_get(token, f"secrets/{slug}")
        if not data:
            print(f"skip {slug}: empty")
            continue
        clean = {k: v for k, v in data.items() if not k.startswith('__')}
        kv_put(token, slug, clean)
        print(f"OK secret/{slug} ({len(clean)} keys)")

    for slug in slugs:
        slug = slug.rstrip('/')
        kv_delete(token, f"secrets/{slug}")
        print(f"DEL secrets/{slug}")

    # Remove empty secrets/ folder if listable
    remaining = list_keys(token, 'secrets')
    if not remaining:
        print('secrets/ prefix cleared')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
