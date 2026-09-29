"""Grader bundle: grader.json (the schema is documented in
/opt/mindforge/grader/run_grade.py) plus the hidden regression tests.

Modes:
  symptom      fresh DB, setup, app restarted, the faults' symptom probes
  regression   fresh DB, setup, the app's regression tests for every feature in
               the history plus every fault carrier (and any regression probes)
  student-test fresh DB, setup, the student's changed tests must fail on the
               baseline commit and pass on their workspace
"""
from __future__ import annotations

import hashlib
import json
from fnmatch import fnmatchcase

from .errors import BuildError
from .inputs import Blocks
from .tree import Tree, block_subtree

REGRESSION_DIR = "regression_tests"
CORE_TESTS = "core"
READINESS_TIMEOUT = 40
MANDATORY_PROTECTED = [".mf/*", ".lab/services/*"]

SETUP_MESSAGE = "The application could not be set up (migrations or data load failed)."
START_MESSAGE = "The application did not start. Check its log and fix the error."
REGRESSION_MESSAGE = "Existing behavior is broken: a previously passing test now fails. Your change may have broken something else."
NO_TEST_MESSAGE = "Add a test that reproduces the bug: it must fail on the original code and pass with your fix."
ON_BASE_MESSAGE = "Your new test passes on the original broken code, so it does not reproduce the bug."
ON_FIX_MESSAGE = "Your new test fails on your current workspace."


def regression_dirs(v: dict, blocks: Blocks) -> list[str]:
    app_dir = v["app"]["dir"]
    features = {h["feature"] for h in v["app"]["history"] if h.get("feature")}
    carriers = {f["carrier"]["feature"] for f in v["faults"]}
    out = []
    for name in [CORE_TESTS, *sorted(features | carriers)]:
        if block_subtree(blocks, app_dir, f"{REGRESSION_DIR}/{name}"):
            out.append(f"{REGRESSION_DIR}/{name}")
        elif name in carriers:
            raise BuildError(f"carrier feature {name!r} has no tests under {REGRESSION_DIR}/{name}/ in the app "
                             "(git revert of the fault commit would not fail the regression suite)")
    if not out:
        raise BuildError(f"the app ships no regression tests under {REGRESSION_DIR}/")
    return out


def protected_manifest(v: dict, files: Tree) -> dict[str, str]:
    patterns = [*v["app"]["protected"], *MANDATORY_PROTECTED]
    return {p: hashlib.sha256(d).hexdigest() for p, d in sorted(files.items())
            if any(fnmatchcase(p, pat) for pat in patterns)}


def build_grader(v: dict, blocks: Blocks, setup: list[str], protected: dict[str, str], baseline_commit: str) -> Tree:
    checks = v["checks"]
    symptom = [c for c in checks if c["role"] == "symptom"]
    regression_probes = [c for c in checks if c["role"] == "regression"]
    if not symptom:
        raise BuildError("no symptom checks: every fault needs at least one")

    def probe(c: dict) -> dict:
        return {"kind": c["probe"], "name": c["name"], "message": c["message"], "params": c["params"]}

    common = {"fresh_db": True, "setup": setup, "setup_message": SETUP_MESSAGE, "start_message": START_MESSAGE}
    reg_paths = regression_dirs(v, blocks)
    modes = {
        "symptom": {**common, "restart_app": True, "needs_app": True, "probes": [probe(c) for c in symptom]},
        "regression": {**common, "restart_app": bool(regression_probes),
                       "tests": [{"name": "Existing behavior still works", "paths": reg_paths, "message": REGRESSION_MESSAGE}],
                       "probes": [probe(c) for c in regression_probes]},
        "student-test": {**common, "restart_app": False,
                         "student_test": {"name": "Regression test for your fix", "test_globs": v["app"]["test_globs"],
                                          "setup": setup, "message_none": NO_TEST_MESSAGE,
                                          "message_on_base": ON_BASE_MESSAGE, "message_on_fix": ON_FIX_MESSAGE}},
    }
    conf = {
        "version": 1,
        "baseline_commit": baseline_commit,
        "app": {"base_url": v["app"]["base_url"], "readiness_path": v["app"]["readiness_path"],
                "readiness_timeout": READINESS_TIMEOUT},
        "protected": protected,
        "env": {},
        "modes": modes,
    }
    files: Tree = {"grader.json": (json.dumps(conf, indent=2, sort_keys=True) + "\n").encode()}
    for path in reg_paths:
        for rel, data in block_subtree(blocks, v["app"]["dir"], path).items():
            files[f"{path}/{rel}"] = data
    return files
