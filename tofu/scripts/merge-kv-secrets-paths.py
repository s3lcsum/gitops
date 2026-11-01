#!/usr/bin/env python3
"""Merge OpenBao KV k8s/<slug> + terraform_env/<slug> → <slug>; delete old paths."""
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


def kv_put(token: str, logical: str, data: dict[str, str]) -> None:
    api(token, 'POST', f"secret/data/{logical}", {'data': data})


def kv_delete(token: str, logical: str) -> None:
    api(token, 'DELETE', f"secret/metadata/{logical}")


def main() -> int:
    cfg = Path.home() / '.config/openbao'
    role_id = read_file(cfg / 'role_id')
    secret_id = read_file(cfg / 'secret_id')
    token = login(role_id, secret_id)

    k8s = list_keys(token, 'k8s')
    tf = list_keys(token, 'terraform_env')
    slugs = sorted(set(k8s) | set(tf))
    if not slugs:
        print('no k8s/ or terraform_env/ keys found', file=sys.stderr)
        return 1

    for slug in slugs:
        merged: dict[str, str] = {}
        for prefix in ('k8s', 'terraform_env'):
            if slug not in (k8s if prefix == 'k8s' else tf):
                continue
            part = kv_get(token, f"{prefix}/{slug}")
            for k, v in part.items():
                if k.startswith('__'):
                    continue
                merged[k] = v
        if not merged:
            print(f"skip {slug}: empty")
            continue
        dest = slug
        kv_put(token, dest, merged)
        print(f"OK {dest} keys={sorted(merged.keys())} ({len(merged)})")

    for slug in k8s:
        kv_delete(token, f"k8s/{slug}")
        print(f"DEL k8s/{slug}")
    for slug in tf:
        kv_delete(token, f"terraform_env/{slug}")
        print(f"DEL terraform_env/{slug}")

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
