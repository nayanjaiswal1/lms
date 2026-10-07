"""Kind J — hidden tests, run with a grader-owned vitest config (React labs).

params:
  paths:  [ "tests/hook_1/stale.test.jsx" ]   files relative to the grader bundle
  args?:  extra vitest args (e.g. ["-t", "countdown"])
  env?:   extra environment for the run (e.g. {"TZ": "America/Los_Angeles"})
  timeout?: seconds (default 60)

The runner never reads the workspace's own vitest/vite configuration: the config
is generated here (root-owned code), tests resolve the app through the "@/"
alias (workspace src/) and the test helpers through "@mf/harness". Results are
read from vitest's JSON report, so "a test failed" (rc 1) is told apart from
"the tests could not run" (rc 2) and "no tests ran" (rc 5).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from typing import Any

from .common import Context, ProbeFailure

KIND = "J"

NODE_MODULES = "/opt/scaffold/react-app/node_modules"
VITEST_ENTRY = NODE_MODULES + "/vitest/vitest.mjs"
HARNESS_DIR = "/opt/mindforge/grader/js"
TEST_TIMEOUT_MS = 15000
DIAGNOSTIC_TAIL = 1800
APP_ALIAS_MARKER = "@@APP_ALIAS@@"
TEST_FILE_GLOB = "/**/*.test.{js,jsx,ts,tsx}"


def link_node_modules(directory: str) -> None:
    """Dependencies are baked into the image; test roots reach them through a symlink."""
    link = os.path.join(directory, "node_modules")
    if os.path.isdir(NODE_MODULES) and not os.path.lexists(link):
        os.symlink(NODE_MODULES, link)


def _config(ctx: Context, root: str, app_dir: str, includes: list[str], report: str) -> str:
    cfg = {
        "root": root,
        "cacheDir": os.path.join(ctx.tmp_dir, "vite-cache"),
        "esbuild": {"jsx": "automatic"},
        "resolve": {
            "alias": [
                {"find": "@mf/harness", "replacement": HARNESS_DIR + "/harness.js"},
                {"find": "@mf/fullstack", "replacement": HARNESS_DIR + "/fullstack.js"},
                {"find": APP_ALIAS_MARKER, "replacement": os.path.join(app_dir, "src") + "/"},
            ],
            "dedupe": ["react", "react-dom"],
        },
        "server": {"fs": {"strict": False}},
        "test": {
            "environment": "jsdom",
            "globals": True,
            "css": False,
            "setupFiles": [HARNESS_DIR + "/setup.js"],
            "include": includes,
            "pool": "forks",
            "testTimeout": TEST_TIMEOUT_MS,
            "hookTimeout": TEST_TIMEOUT_MS,
            "watch": False,
            "reporters": ["json"],
            "outputFile": {"json": report},
        },
    }
    path = os.path.join(ctx.tmp_dir, f"vitest-{os.path.basename(report)}.mjs")
    # The "@/" alias is a regular expression, which JSON cannot express.
    body = json.dumps(cfg, indent=2).replace(json.dumps(APP_ALIAS_MARKER), "/^@\\//")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("export default " + body + ";\n")
    return path


def _include(target: str, root: str) -> str:
    """A target file stays itself; a directory means every test file below it."""
    path = target.split("::", 1)[0]
    rel = os.path.relpath(path, root)
    return rel + TEST_FILE_GLOB if os.path.isdir(path) else rel


def run_vitest(ctx: Context, targets: list[str], root: str, app_dir: str, extra: list[str] | None = None,
               env: dict[str, str] | None = None, timeout: int = 60, diagnose: bool = True) -> int:
    """Run vitest on absolute `targets` (all below `root`) against the app in
    `app_dir`. Returns 0 when every test passed, 1 when a test failed, 2 when
    the run broke before testing (import/syntax error), 5 when no test ran,
    124 on timeout."""
    link_node_modules(root)
    includes = [_include(t, root) for t in targets]
    fd, report = tempfile.mkstemp(prefix="report-", suffix=".json", dir=ctx.tmp_dir)
    os.close(fd)
    cfg = _config(ctx, root, app_dir, includes, report)
    run_env = dict(os.environ)
    run_env.update(ctx.env)
    run_env.update(env or {})
    run_env.pop("NODE_OPTIONS", None)
    run_env["CI"] = "1"
    try:
        proc = subprocess.run(["node", VITEST_ENTRY, "run", "--config", cfg, "--root", root, *(extra or [])],
                              cwd=root, env=run_env, capture_output=True, text=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        return 124
    try:
        with open(report, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        data = None
    if data is None:
        rc = 2
    elif data.get("numTotalTests", 0) == 0:
        rc = 2 if data.get("numFailedTestSuites", 0) else 5
    elif data.get("numFailedTests", 0) > 0:
        rc = 1
    elif data.get("success"):
        rc = 0
    else:
        rc = 2
    if rc != 0 and diagnose:
        failed = [f"{t.get('fullName', '?')}: {' '.join(t.get('failureMessages', []))[:300]}"
                  for f in (data or {}).get("testResults", []) for t in f.get("assertionResults", [])
                  if t.get("status") == "failed"]
        detail = "\n".join(failed) or (proc.stdout + proc.stderr)
        sys.stderr.write(f"[vitest rc={rc}] {detail[-DIAGNOSTIC_TAIL:]}\n")
    return rc


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    from .t_test import resolve_targets

    rc = run_vitest(ctx, resolve_targets(ctx, params["paths"]), ctx.grader_dir, ctx.workdir, params.get("args"),
                    params.get("env"), int(params.get("timeout", 60)))
    if rc != 0:
        raise ProbeFailure("")
