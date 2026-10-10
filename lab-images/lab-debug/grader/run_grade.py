#!/usr/bin/env python3
"""Generic grader engine behind /opt/mindforge/grade.sh.

Invoked by grade.sh AFTER it has extracted the grader bundle. Nothing in here
knows any lab kind's mode names: the modes come from the bundle's grader.json
(the lab kind's configuration), e.g. for the debug kind: symptom, regression,
student-test.

grader.json (version 1):
{
  "baseline_commit": "<git ref in the workspace>",          # student-test
  "app": {"base_url": "http://127.0.0.1:8000", "readiness_path": "/", "readiness_timeout": 40},
  "database": {"url_template": "postgresql://labuser@127.0.0.1:5432/{db}", "env": "DATABASE_URL"},
  "protected": {"path/in/workspace": "<sha256>"},           # integrity manifest
  "env": {"EXTRA": "value"},                                # extra env for setup/app/tests
  "modes": {
    "<mode>": {
      "fresh_db": true, "restart_app": true,
      "setup": ["shell command", ...],                      # run in the workspace
      "tests": [{"name", "paths": [...], "args": [...], "message", "runner": "pytest|vitest|mixed"}],
      "probes": [{"kind": "P|Q|C|M|L|H|T|J", "name", "message", "params": {...}}],
      "student_test": {"runner": "pytest|vitest|mixed (by file extension)", "test_globs": [...], "setup": [...], "message_none", "message_on_base", "message_on_fix"}
    }
  }
}

Output (stdout, the ONLY thing written there): one JSON object
{"mode", "passed", "checks": [{"name", "passed", "message"?}], "error"?} with
author-written messages only. Diagnostics go to stderr, which the platform
logs but never shows to the student.
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.probes import INFRA_MESSAGE, run_probe  # noqa: E402
from lib.probes.common import Context  # noqa: E402
from lib.probes.j_vitest import run_vitest  # noqa: E402
from lib.probes.t_test import resolve_targets, run_pytest  # noqa: E402

STARTUP_HOOK_NAMES = {"sitecustomize.py", "usercustomize.py"}
SKIP_DIRS = {".git", "node_modules", ".venv", "__pycache__"}
MAX_SETUP_SECONDS = 60


def emit(mode: str, checks: list[dict], error: str = "") -> None:
    passed = bool(checks) and all(c["passed"] for c in checks) and not error
    out: dict = {"mode": mode, "passed": passed, "checks": checks}
    if error:
        out["error"] = error
    print(json.dumps(out))


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def integrity_check(workdir: str, protected: dict[str, str]) -> dict:
    """Protected files must match the pristine manifest; interpreter startup
    hooks (sitecustomize/usercustomize/*.pth) are never allowed. In the
    clean-room flow protected paths are never copied from the student, so this
    is a safety net, not the primary defense."""
    for rel, want in protected.items():
        path = os.path.realpath(os.path.join(workdir, rel))
        if not path.startswith(os.path.realpath(workdir) + os.sep) or not os.path.isfile(path) \
                or sha256_file(path) != want:
            return {"name": "integrity", "passed": False,
                    "message": "A protected file was modified. Restore it and try again."}
    for root, dirs, files in os.walk(workdir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if name in STARTUP_HOOK_NAMES or name.endswith(".pth"):
                return {"name": "integrity", "passed": False,
                        "message": "Python startup hooks (sitecustomize, usercustomize, .pth) are not allowed."}
    return {"name": "integrity", "passed": True}


def psql_admin(sql: str) -> bool:
    proc = subprocess.run(
        ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-h", "127.0.0.1", "-U", "labuser", "-d", "template1", "-c", sql],
        capture_output=True, text=True, timeout=30, check=False)
    return proc.returncode == 0


def run_shell(ctx: Context, cmd: str, cwd: str | None = None, extra_env: dict | None = None) -> bool:
    env = dict(os.environ)
    env.update(ctx.env)
    env.update(extra_env or {})
    try:
        proc = subprocess.run(["bash", "-c", cmd], cwd=cwd or ctx.workdir, env=env, capture_output=True,
                              text=True, timeout=MAX_SETUP_SECONDS, check=False)
    except subprocess.TimeoutExpired:
        return False
    if proc.returncode != 0:
        sys.stderr.write(f"[grade] setup command failed ({proc.returncode}): {cmd}\n{proc.stderr[-2000:]}\n")
    return proc.returncode == 0


def restart_app(ctx: Context, app: dict, env_pairs: list[str]) -> bool:
    if subprocess.run(["mf-svc", "set-env", *env_pairs], check=False).returncode != 0:
        return False
    if subprocess.run(["mf-svc", "restart-workspace"], check=False).returncode != 0:
        return False
    time.sleep(1.5)  # let the old process group die and the supervisor respawn
    url = app.get("base_url", "http://127.0.0.1:8000").rstrip("/") + app.get("readiness_path", "/")
    return subprocess.run(["mf-svc", "wait-ready", url, str(app.get("readiness_timeout", 40))],
                          check=False).returncode == 0


def run_tests(ctx: Context, runner: str, targets: list[str], root: str, app_dir: str, extra: list[str] | None = None,
              diagnose: bool = True) -> int:
    """One test run in the configured runner. `root` holds the test files,
    `app_dir` is the workspace tree the tests exercise."""
    if runner == "mixed":
        return run_mixed(ctx, targets, root, app_dir, extra, diagnose)
    if runner == "vitest":
        return run_vitest(ctx, targets, root, app_dir, extra, diagnose=diagnose)
    return run_pytest(ctx, targets, extra, cwd=app_dir)


def run_mixed(ctx: Context, targets: list[str], root: str, app_dir: str, extra: list[str] | None, diagnose: bool) -> int:
    """Fullstack apps: Python files run in pytest, everything else in vitest. 1 (a test failed) wins over
    other non-zero codes, so "fails on the baseline" holds when either side's test fails."""
    py = [t for t in targets if t.split("::", 1)[0].endswith(".py")]
    js = [t for t in targets if t not in py]
    codes = []
    if py:
        codes.append(run_pytest(ctx, py, extra, cwd=app_dir))
    if js:
        codes.append(run_vitest(ctx, js, root, app_dir, extra, diagnose=diagnose))
    return 1 if 1 in codes else next((c for c in codes if c), 0)


def git(ctx: Context, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", *args], cwd=ctx.workdir, capture_output=True, text=True, timeout=30, check=False)


def student_test_checks(ctx: Context, cfg: dict, conf: dict) -> list[dict]:
    """The student's added/changed tests must FAIL on the pristine baseline
    (a content-addressed git worktree) and PASS on their workspace."""
    st = conf["student_test"]
    runner = st.get("runner", "pytest")
    baseline = cfg.get("baseline_commit") or conf.get("baseline_commit", "")
    name = st.get("name", "student regression test")
    if not baseline or git(ctx, "cat-file", "-e", baseline + "^{commit}").returncode != 0:
        return [{"name": name, "passed": False, "message": INFRA_MESSAGE}]

    changed = git(ctx, "status", "--porcelain", "--untracked-files=all").stdout.splitlines()
    diff = git(ctx, "diff", "--name-only", "--diff-filter=AM", baseline).stdout.splitlines()
    candidates = {line[3:] for line in changed} | set(diff)
    tests = sorted(p for p in candidates
                   if any(fnmatch.fnmatch(p, g) for g in st.get("test_globs", ["tests/*", "*/test_*.py", "test_*.py"])))
    if not tests:
        return [{"name": name, "passed": False, "message": st.get("message_none", "")}]

    base = os.path.join(ctx.tmp_dir, "baseline")
    if git(ctx, "worktree", "add", "--detach", base, baseline).returncode != 0:
        return [{"name": name, "passed": False, "message": INFRA_MESSAGE}]
    base_db = ctx.db_name + "_base"
    try:
        for rel in tests:
            src = os.path.join(ctx.workdir, rel)
            if os.path.isfile(src):
                dst = os.path.join(base, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                with open(src, "rb") as fi, open(dst, "wb") as fo:
                    fo.write(fi.read())
        psql_admin(f'DROP DATABASE IF EXISTS "{base_db}"')
        if not psql_admin(f'CREATE DATABASE "{base_db}"'):
            return [{"name": name, "passed": False, "message": INFRA_MESSAGE}]
        base_url = ctx.db_url.rsplit("/", 1)[0] + "/" + base_db
        base_env = {cfg.get("database", {}).get("env", "DATABASE_URL"): base_url, "MF_WORKDIR": base}
        for cmd in st.get("setup", []):
            run_shell(ctx, cmd, cwd=base, extra_env=base_env)
        base_ctx = Context(**{**ctx.__dict__, "workdir": base, "env": {**ctx.env, **base_env}})
        on_base = run_tests(base_ctx, runner, [os.path.join(base, t) for t in tests], base, base, diagnose=False)
        on_fix = run_tests(ctx, runner, [os.path.join(ctx.workdir, t) for t in tests], ctx.workdir, ctx.workdir)
    finally:
        git(ctx, "worktree", "remove", "--force", base)
        psql_admin(f'DROP DATABASE IF EXISTS "{base_db}" WITH (FORCE)')
    checks = [
        {"name": name + " fails on the broken baseline", "passed": on_base == 1,
         **({} if on_base == 1 else {"message": st.get("message_on_base", "")})},
        {"name": name + " passes on your fix", "passed": on_fix == 0,
         **({} if on_fix == 0 else {"message": st.get("message_on_fix", "")})},
    ]
    return checks


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--grader-dir", required=True)
    ap.add_argument("--workdir", required=True)
    ap.add_argument("--tmp", required=True)
    ap.add_argument("--db", required=True)
    a = ap.parse_args()

    try:
        with open(os.path.join(a.grader_dir, "grader.json"), encoding="utf-8") as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        emit(a.mode, [], "The grader bundle is unreadable.")
        return 0
    conf = cfg.get("modes", {}).get(a.mode)
    if conf is None:
        emit(a.mode, [], "Unknown grading mode.")
        return 0

    db_cfg = cfg.get("database", {})
    db_url = db_cfg.get("url_template", "postgresql://labuser@127.0.0.1:5432/{db}").format(db=a.db)
    db_env = db_cfg.get("env", "DATABASE_URL")
    app = cfg.get("app", {})
    ctx_env = {**cfg.get("env", {}), db_env: db_url, "MF_SEED": a.seed, "MF_GRADER_DIR": a.grader_dir,
               "MF_WORKDIR": a.workdir}
    ctx = Context(base_url=app.get("base_url", "http://127.0.0.1:8000"), seed=a.seed, db_name=a.db, db_url=db_url,
                  workdir=a.workdir, grader_dir=a.grader_dir, tmp_dir=a.tmp, env=ctx_env)

    checks: list[dict] = []
    integrity = integrity_check(a.workdir, cfg.get("protected", {}))
    if not integrity["passed"]:
        emit(a.mode, [integrity])
        return 0

    if conf.get("fresh_db", True):
        psql_admin(f'DROP DATABASE IF EXISTS "{a.db}"')
        if not psql_admin(f'CREATE DATABASE "{a.db}"'):
            emit(a.mode, [], INFRA_MESSAGE)
            return 0
    for cmd in conf.get("setup", []):
        if not run_shell(ctx, cmd):
            emit(a.mode, [{"name": "setup", "passed": False,
                           "message": conf.get("setup_message", "The application could not be set up (migrations or data load failed).")}])
            return 0

    if conf.get("restart_app", True) and (conf.get("probes") or conf.get("needs_app")):
        pairs = [f"{k}={v}" for k, v in ctx_env.items()]
        if not restart_app(ctx, app, pairs):
            emit(a.mode, [{"name": "application starts", "passed": False,
                           "message": conf.get("start_message", "The application did not start.")}])
            return 0

    for group in conf.get("tests", []):
        rc = run_tests(ctx, group.get("runner", "pytest"), resolve_targets(ctx, group["paths"]), ctx.grader_dir,
                       ctx.workdir, group.get("args"))
        ok = rc == 0
        checks.append({"name": group.get("name", "tests"), "passed": ok,
                       **({} if ok else {"message": group.get("message", "")})})
    for spec in conf.get("probes", []):
        checks.append(run_probe(ctx, spec))
    if conf.get("student_test"):
        checks.extend(student_test_checks(ctx, cfg, conf))

    emit(a.mode, checks)
    return 0


if __name__ == "__main__":
    sys.exit(main())
