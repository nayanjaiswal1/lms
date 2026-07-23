#!/usr/bin/env python3
"""Flag drift between docs/flow-map.md and the live codebase.

Read-only. Parses docs/flow-map.md as ground truth (DB tables mentioned per
feature, backend packages mentioned via internal/<pkg>/ paths in Handlers
lines) and diffs that against:
  - backend/internal/* package directories
  - CREATE TABLE statements in backend/db/migrations/*.sql

It does not rewrite the doc — the doc's prose (grouping, "notable hops") is
curated by hand/AI, not mechanically regenerable. This only tells you what
changed in the code since the doc was last updated.

Exit code: 0 if nothing found, 1 if drift found.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "flow-map.md"
MIGRATIONS = ROOT / "backend" / "db" / "migrations"
INTERNAL = ROOT / "backend" / "internal"

# Packages that are cross-cutting plumbing, not user-facing features —
# never expected to have a docs/flow-map.md section of their own.
INFRA_PACKAGES = {"api", "config", "db", "httputil", "middleware"}


def parse_doc(text: str):
    """Return (documented_tables, documented_packages)."""
    tables = set()
    packages = set()
    for line in text.splitlines():
        m = re.match(r"\*\*DB:?\*\*\s*(.+)", line)
        if m:
            # Table names are consistently written as backtick code spans
            # (`courses`, `enrollments`) — pull those directly rather than
            # splitting on commas, which also appear inside plain prose.
            for tok in re.findall(r"`([a-z][a-z0-9_]*)`", m.group(1)):
                tables.add(tok)
        for pkg in re.findall(r"internal/([a-zA-Z_]+)/", line):
            packages.add(pkg)
    return tables, packages


def live_tables():
    tables = set()
    for f in sorted(MIGRATIONS.glob("*.sql")):
        if f.name.endswith(".down.sql"):
            continue
        text = f.read_text(encoding="utf-8", errors="ignore")
        tables.update(re.findall(r"CREATE TABLE\s+public\.(\w+)", text, re.IGNORECASE))
    return tables


def live_packages():
    return {p.name for p in INTERNAL.iterdir() if p.is_dir()}


def main():
    if not DOC.exists():
        print(f"error: {DOC} not found", file=sys.stderr)
        return 2

    doc_tables, doc_packages = parse_doc(DOC.read_text(encoding="utf-8"))
    code_tables = live_tables()
    code_packages = live_packages() - INFRA_PACKAGES

    missing_tables = sorted(code_tables - doc_tables)
    missing_packages = sorted(code_packages - doc_packages)
    stale_tables = sorted(doc_tables - code_tables)

    found = False

    if missing_packages:
        found = True
        print(f"Backend packages with no flow-map.md section ({len(missing_packages)}):")
        for p in missing_packages:
            print(f"  - backend/internal/{p}/")
        print()

    if missing_tables:
        found = True
        print(f"DB tables not mentioned in any flow-map.md **DB:** line ({len(missing_tables)}):")
        for t in missing_tables:
            print(f"  - {t}")
        print()

    if stale_tables:
        found = True
        print(f"Tables in flow-map.md that no longer exist in migrations ({len(stale_tables)}):")
        for t in stale_tables:
            print(f"  - {t}")
        print()

    if not found:
        print("No drift detected: every backend package and DB table is referenced in docs/flow-map.md.")
        return 0

    print("Update docs/flow-map.md (and republish the artifact if you keep one) to cover the above.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
