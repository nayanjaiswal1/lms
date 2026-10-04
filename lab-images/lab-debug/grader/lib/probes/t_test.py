"""Kind T — hidden tests, run with a hardened pytest.

params:
  paths:  [ "tests/symptom", "tests/test_x.py::test_y" ]   relative to the grader bundle
  args?:  extra pytest args (e.g. ["-k", "money"])
The runner ignores everything the workspace could use to tamper with it:
isolated interpreter (-I), no conftest, no cache provider, a grader-owned
config file, and rootdir/pythonpath pinned by the grader.
"""
from __future__ import annotations

import os
import subprocess
from typing import Any

from .common import Context, ProbeFailure

KIND = "T"


def pytest_command(ctx: Context, targets: list[str], extra: list[str] | None = None) -> list[str]:
    """Build the hardened pytest command (used by kind T and by grade tests)."""
    cfg = os.path.join(ctx.tmp_dir, "pytest.ini")
    if not os.path.exists(cfg):
        with open(cfg, "w", encoding="utf-8") as f:
            f.write("[pytest]\n")
    return [
        "python3", "-I", "-m", "pytest",
        "--noconftest", "-p", "no:cacheprovider",
        "-c", cfg, f"--rootdir={ctx.tmp_dir}",
        "-o", f"pythonpath={ctx.workdir}",
        "-q", "-x", "--no-header",
        *(extra or []),
        *targets,
    ]


def run_pytest(ctx: Context, targets: list[str], extra: list[str] | None = None,
               cwd: str | None = None, timeout: int = 60) -> int:
    env = dict(os.environ)
    env.update(ctx.env)
    try:
        proc = subprocess.run(pytest_command(ctx, targets, extra), cwd=cwd or ctx.workdir, env=env,
                              capture_output=True, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        return 124
    return proc.returncode


def resolve_targets(ctx: Context, paths: list[str]) -> list[str]:
    """Map grader-relative paths to absolute ones, refusing escapes."""
    root = os.path.realpath(ctx.grader_dir)
    out: list[str] = []
    for p in paths:
        file_part = p.split("::", 1)[0]
        real = os.path.realpath(os.path.join(root, file_part))
        if not (real == root or real.startswith(root + os.sep)):
            raise ProbeFailure("")
        out.append(os.path.join(root, p))
    return out


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    rc = run_pytest(ctx, resolve_targets(ctx, params["paths"]), params.get("args"),
                    timeout=int(params.get("timeout", 60)))
    if rc != 0:
        raise ProbeFailure("")
