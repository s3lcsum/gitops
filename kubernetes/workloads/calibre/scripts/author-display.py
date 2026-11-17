#!/usr/bin/env python3
"""Render author separators as commas in Calibre-Web Automated v4.0.8."""

import re
import sys
from pathlib import Path


APP = Path('/app/calibre-web-automated/cps')
GRID_DIVIDER = re.compile(
    r'(<span(?: class="author-hidden-divider")?>)&amp;(</span>)'
)
INLINE_DIVIDER = re.compile(
    r'\s*{% if not loop.last %}\s*&amp;\s*{% endif %}'
)
TABLE_ANCHOR = '        column.push(element);'
TABLE_DISPLAY = """        if (["authors", "author_sort"].includes($(this).attr("data-field"))) {
            const commaSeparated = (value) => typeof value === "string"
                ? value.replace(/ &(?:amp;)? /g, ", ")
                : value;
            if (element.editable) {
                element.editable.display = function (value) {
                    $(this).text(commaSeparated(value) || "");
                };
            } else {
                element.formatter = commaSeparated;
            }
        }
        column.push(element);"""


def apply(root):
    pending = {}
    for name, expected in {
        'index': 4, 'search': 2, 'shelf': 2, 'author': 2,
        'detail': 1, 'shelfdown': 1, 'shelf_order': 1, 'listenmp3': 1,
    }.items():
        path = root / 'templates' / f"{name}.html"
        source = path.read_text(encoding='utf-8')
        divider = GRID_DIVIDER if expected > 1 else INLINE_DIVIDER
        replacement = r'\1, \2' if expected > 1 else '{% if not loop.last %}, {% endif %}'
        updated, count = divider.subn(replacement, source)
        if count not in (0, expected):
            raise ValueError(f"Unexpected author separators in {path}: {count}")
        pending[path] = updated

    table = root / 'static/js/table.js'
    source = table.read_text(encoding='utf-8')
    if TABLE_DISPLAY not in source:
        if source.count(TABLE_ANCHOR) != 1:
            raise ValueError(f"Unexpected author column setup in {table}")
        pending[table] = source.replace(TABLE_ANCHOR, TABLE_DISPLAY, 1)

    for path, source in pending.items():
        if path.read_text(encoding='utf-8') != source:
            path.write_text(source, encoding='utf-8')


if __name__ == '__main__':
    try:
        apply(Path(sys.argv[1]) if len(sys.argv) > 1 else APP)
    except (OSError, ValueError) as error:
        print(f"Calibre author display patch skipped: {error}", file=sys.stderr)
        sys.exit(1)
