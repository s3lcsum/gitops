#!/usr/bin/env python3
"""Apply a JSON seed of non-default settings onto a single-row SQLite table.

Usage:
    python3 Makefile.settings-apply.py --db /path/app.db --table settings \
        --seed /path/app_settings.json [--id 1]
    python3 Makefile.settings-apply.py --db /path/cwa.db --table cwa_settings \
        --seed /path/cwa_settings.json

Jumps over a column named 'id'; for cwa_settings (no id column) every seed
key is applied. Values that are dict/list are JSON-serialised for storage.
"""
import argparse, json, sqlite3, sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--table", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--id", type=int, default=None)
    a = ap.parse_args()

    with open(a.seed) as f:
        seed = json.load(f)

    conn = sqlite3.connect(a.db)
    conn.execute("PRAGMA journal_mode=WAL")
    cur = conn.cursor()
    cols = [r[1] for r in cur.execute(f"PRAGMA table_info({a.table})")]
    rows = cur.execute(f"SELECT * FROM {a.table}").fetchall()
    if not rows:
        print(f"ERROR: {a.table} has no rows", file=sys.stderr)
        sys.exit(1)

    target = None
    if a.id is not None:
        for row in rows:
            if row[0] == a.id:
                target = row
                break
        if target is None:
            print(f"ERROR: no row with id={a.id} in {a.table}", file=sys.stderr)
            sys.exit(1)
    else:
        target = rows[0]

    has_id = "id" in cols
    row_id = target[cols.index("id")] if has_id else None

    updates = []
    for key, value in seed.items():
        if key not in cols:
            print(f"WARN: column {key!r} not found in {a.table}; skipped")
            continue
        if key == "id":
            continue
        stored = json.dumps(value) if isinstance(value, (dict, list)) else value
        updates.append((key, stored, row_id))

    if a.id is None and has_id:
        where = f"WHERE id = {row_id}"
    elif a.id is not None:
        where = f"WHERE id = {a.id}"
    else:
        where = ""

    if not updates:
        print("no columns to update")
        return

    set_clause = ", ".join(f"{k} = ?" for k, _, _ in updates)
    cur.execute(f"UPDATE {a.table} SET {set_clause} {where}", [v for _, v, _ in updates])
    conn.commit()
    print(f"applied {len(updates)} settings to {a.table}{' (id=%d)' % row_id if has_id else ''}")


if __name__ == "__main__":
    main()