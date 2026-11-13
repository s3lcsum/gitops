#!/usr/bin/env python3
"""Apply GitOps seeds before Calibre-Web Automated starts (CWA must be down)."""
from __future__ import annotations

import hashlib
import io
import json
import os
import sqlite3
import sys
import urllib.request
import zipfile
from pathlib import Path

SEED_DIR = Path(os.environ.get("CWA_SEED_DIR", "/bootstrap"))
CONFIG = Path("/config")
CALIBRE_CFG = CONFIG / ".config" / "calibre"
PLUGIN_DIR = CALIBRE_CFG / "plugins"
PLUGIN_PATH = PLUGIN_DIR / "DeDRM.zip"

DEDRM_RELEASE_URL = (
    "https://github.com/noDRM/DeDRM_tools/releases/download/v10.0.3/DeDRM_tools_10.0.3.zip"
)
DEDRM_PLUGIN_SHA256 = (
    "83be7a30b6f7ff893a811ac3c53d397ceeb97bc38e3a43e946d2d87baab64a07"
)


def log(msg: str) -> None:
    print(msg, flush=True)


def apply_table_seed(db_path: Path, table: str, seed_path: Path, row_id: int | None) -> None:
    if not db_path.is_file():
        log(f"skip settings: {db_path} not found yet (restart once after first boot)")
        return

    with open(seed_path) as f:
        seed = json.load(f)

    conn = sqlite3.connect(db_path)
    try:
        conn.execute("PRAGMA journal_mode=DELETE")
        cur = conn.cursor()
        cols = [r[1] for r in cur.execute(f"PRAGMA table_info({table})")]
        rows = cur.execute(f"SELECT * FROM {table}").fetchall()
        if not rows:
            print(f"ERROR: {table} has no rows in {db_path}", file=sys.stderr)
            sys.exit(1)

        target = None
        if row_id is not None:
            for row in rows:
                if row[0] == row_id:
                    target = row
                    break
            if target is None:
                print(f"ERROR: no row id={row_id} in {table}", file=sys.stderr)
                sys.exit(1)
        else:
            target = rows[0]

        updates: list[tuple[str, object]] = []
        for key, value in seed.items():
            if key not in cols or key == "id":
                if key not in cols and key != "id":
                    log(f"WARN: column {key!r} missing in {table}; skipped")
                continue
            stored = json.dumps(value) if isinstance(value, (dict, list)) else value
            updates.append((key, stored))

        if not updates:
            log(f"no columns to update in {table}")
            return

        if row_id is not None:
            where = f"WHERE id = {row_id}"
        elif "id" in cols:
            where = f"WHERE id = {target[cols.index('id')]}"
        else:
            where = ""

        set_clause = ", ".join(f"{k} = ?" for k, _ in updates)
        cur.execute(
            f"UPDATE {table} SET {set_clause} {where}",
            [v for _, v in updates],
        )
        conn.commit()
        log(f"applied {len(updates)} keys to {table}")
    finally:
        conn.close()


def install_dedrm() -> None:
    PLUGIN_DIR.mkdir(parents=True, exist_ok=True)
    CALIBRE_CFG.mkdir(parents=True, exist_ok=True)

    log(f"fetching DeDRM from {DEDRM_RELEASE_URL}")
    with urllib.request.urlopen(DEDRM_RELEASE_URL, timeout=120) as resp:
        release = resp.read()

    with zipfile.ZipFile(io.BytesIO(release)) as zf:
        plugin_name = "DeDRM_plugin.zip"
        if plugin_name not in zf.namelist():
            print(f"ERROR: {plugin_name} not in release zip", file=sys.stderr)
            sys.exit(1)
        data = zf.read(plugin_name)

    digest = hashlib.sha256(data).hexdigest()
    if digest != DEDRM_PLUGIN_SHA256:
        print(
            f"ERROR: DeDRM plugin sha256 mismatch (got {digest})",
            file=sys.stderr,
        )
        sys.exit(1)

    PLUGIN_PATH.write_bytes(data)
    log("installed DeDRM plugin")

    customize_src = SEED_DIR / "customize.py.json"
    customize_dst = CALIBRE_CFG / "customize.py.json"
    customize_dst.write_bytes(customize_src.read_bytes())

    with open(SEED_DIR / "dedrm.base.json") as f:
        dedrm = json.load(f)

    adept_env = os.environ.get("DEDRM_ADEPTKEYS", "").strip()
    if adept_env:
        try:
            parsed = json.loads(adept_env)
            if isinstance(parsed, dict):
                dedrm["adeptkeys"] = parsed
                log("merged DEDRM_ADEPTKEYS into dedrm.json")
        except json.JSONDecodeError as exc:
            log(f"WARN: invalid DEDRM_ADEPTKEYS JSON: {exc}")

    (PLUGIN_DIR / "dedrm.json").write_text(json.dumps(dedrm, indent=2) + "\n")


def main() -> None:
    install_dedrm()
    apply_table_seed(
        CONFIG / "cwa.db",
        "cwa_settings",
        SEED_DIR / "cwa_settings.json",
        row_id=None,
    )
    apply_table_seed(
        CONFIG / "app.db",
        "settings",
        SEED_DIR / "app_settings.json",
        row_id=1,
    )
    log("cwa-bootstrap complete")


if __name__ == "__main__":
    main()
