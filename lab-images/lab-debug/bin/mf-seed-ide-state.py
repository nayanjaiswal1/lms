#!/usr/bin/env python3
"""Build-time seed of the IDE's UI state: hide the Explorer's Outline and
Timeline panes so the file list (and INCIDENT.md) gets the whole sidebar.

VS Code has no setting for this; pane visibility lives in the profile's
state.vscdb. Usage: mf-seed-ide-state.py <user-data-dir>
"""
import json
import os
import sqlite3
import sys

HIDDEN_VIEWS = ["outline", "timeline"]
# Both keys: the per-container state and the legacy hidden-views list.
STATE_KEYS = ("workbench.view.explorer.state.hidden", "workbench.explorer.views.state")


def main() -> int:
    store_dir = os.path.join(sys.argv[1], "User", "globalStorage")
    os.makedirs(store_dir, exist_ok=True)
    db = sqlite3.connect(os.path.join(store_dir, "state.vscdb"))
    db.execute("CREATE TABLE IF NOT EXISTS ItemTable (key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB)")
    value = json.dumps([{"id": v, "isHidden": True} for v in HIDDEN_VIEWS])
    db.executemany("INSERT INTO ItemTable (key, value) VALUES (?, ?)", [(k, value) for k in STATE_KEYS])
    db.commit()
    db.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
