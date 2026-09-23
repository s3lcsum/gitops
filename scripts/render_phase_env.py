#!/usr/bin/env python3
"""Render compose .env files from Phase (https://phase.dominiksiejak.pl).

If PHASE_SERVICE_TOKEN is unset (and no token file), skip so the Phase stack
itself can boot. Once a token is configured, every mapped app must export
successfully — apply must not rsync half-empty env files.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
DEFAULT_MAP = REPO / 'scripts' / 'phase_env_map.yaml'
DEFAULT_HOST = 'https://phase.dominiksiejak.pl'


def token_from_env(token_file: Path | None) -> str:
    tok = os.environ.get('PHASE_SERVICE_TOKEN', '').strip()
    if tok:
        return tok
    if token_file and token_file.is_file():
        return token_file.read_text().strip()
    return ''


def load_map(path: Path) -> tuple[list[dict], set[str]]:
    raw = yaml.safe_load(path.read_text()) or {}
    apps = raw.get('apps') or []
    bootstrap = set(raw.get('bootstrap') or [])
    return apps, bootstrap


def phase_export(app: str, env: str, host: str, token: str) -> str:
    proc = subprocess.run(
        [
            'phase',
            'secrets',
            'export',
            '--app',
            app,
            '--env',
            env,
            '--format',
            'dotenv',
        ],
        check=False,
        capture_output=True,
        text=True,
        env={**os.environ, 'PHASE_HOST': host, 'PHASE_SERVICE_TOKEN': token},
    )
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or 'phase export failed').strip()
        raise RuntimeError(f'{app}/{env}: {err}')
    return proc.stdout


def render(
    dest: Path,
    mapping: Path,
    host: str,
    token: str,
    exporter=phase_export,
) -> list[Path]:
    apps, _bootstrap = load_map(mapping)
    written = []
    payloads = []
    for item in apps:
        rel = item['path']
        name = item['app']
        env = item.get('env', 'prod')
        body = exporter(name, env, host, token)
        payloads.append((dest / rel, body))
    for path, body in payloads:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body if body.endswith('\n') else body + '\n')
        written.append(path)
    return written


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dest', type=Path, default=REPO / 'stacks')
    parser.add_argument('--map', type=Path, default=DEFAULT_MAP)
    parser.add_argument('--host', default=os.environ.get('PHASE_HOST', DEFAULT_HOST))
    parser.add_argument(
        '--token-file',
        type=Path,
        default=Path(os.environ.get('PHASE_TOKEN_FILE', REPO / '.phase-service-token')),
    )
    args = parser.parse_args(argv)

    token = token_from_env(args.token_file)
    if not token:
        print('render_phase_env: PHASE_SERVICE_TOKEN unset — skip (bootstrap mode)')
        return 0

    try:
        written = render(args.dest, args.map, args.host, token)
    except Exception as exc:
        print(f'render_phase_env: {exc}', file=sys.stderr)
        return 1

    print(f'render_phase_env: wrote {len(written)} env files under {args.dest}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
