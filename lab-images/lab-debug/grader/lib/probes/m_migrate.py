"""Kind M — migrations from a clean DB AND from a seeded "prod snapshot".

params:
  steps: [
    { db: "clean" | "snapshot",
      snapshot_sql: "fixtures/prod_snapshot.sql"   # relative to the grader bundle (snapshot only)
      cmd: "python manage.py migrate --noinput",   # run in the workspace
      expect_rc: 0,                                # default 0
      post_sql: [ {sql, equals?|min?|max?} ],      # checked against that scratch DB
      timeout: 60 }
  ]
Each step gets its own scratch database (created from template1, dropped
afterwards) exposed to the command as DATABASE_URL, so steps never see each
other's state. `makemigrations --check` / `alembic check` are just steps with
expect_rc 0.
"""
from __future__ import annotations

import os
import subprocess
from typing import Any

from .common import Context, ProbeFailure, psql, run_command

KIND = "M"


def _admin(ctx: Context, sql: str) -> None:
    psql(ctx, sql, db="template1")


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    for i, step in enumerate(params.get("steps", [])):
        scratch = f"{ctx.db_name}_m{i}"
        url = ctx.db_url.rsplit("/", 1)[0] + "/" + scratch
        _admin(ctx, f'DROP DATABASE IF EXISTS "{scratch}"')
        _admin(ctx, f'CREATE DATABASE "{scratch}"')
        try:
            if step.get("db") == "snapshot":
                snap = os.path.realpath(os.path.join(ctx.grader_dir, step["snapshot_sql"]))
                if not snap.startswith(os.path.realpath(ctx.grader_dir) + os.sep):
                    raise ProbeFailure("")
                loaded = subprocess.run(
                    ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-h", "127.0.0.1", "-U", "labuser",
                     "-d", scratch, "-f", snap],
                    capture_output=True, text=True, timeout=60, check=False,
                )
                if loaded.returncode != 0:
                    raise ProbeFailure("")
            try:
                proc = run_command(ctx, step["cmd"], extra_env={"DATABASE_URL": url},
                                   timeout=int(step.get("timeout", 60)))
            except subprocess.TimeoutExpired:
                raise ProbeFailure("") from None
            if proc.returncode != int(step.get("expect_rc", 0)):
                raise ProbeFailure("")
            for chk in step.get("post_sql", []):
                raw = psql(ctx, chk["sql"], db=scratch)
                try:
                    val: Any = float(raw)
                except ValueError:
                    val = raw
                if "equals" in chk and val != chk["equals"]:
                    raise ProbeFailure("")
                if "min" in chk and not (isinstance(val, float) and val >= chk["min"]):
                    raise ProbeFailure("")
                if "max" in chk and not (isinstance(val, float) and val <= chk["max"]):
                    raise ProbeFailure("")
        finally:
            _admin(ctx, f'DROP DATABASE IF EXISTS "{scratch}" WITH (FORCE)')
