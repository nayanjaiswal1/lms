"""Hand-made scenarios (`custom` blocks): the block carries the whole scenario
under custom.root instead of an app + fault composition.

    <root>/scenario.json    {"title", "language": python|js|fullstack, "setup": [cmd], "ports": [n], "protected": [glob],
                             "test_globs": [glob], "readiness_path", "root_cause_md", "rubric": {key_points, misconceptions},
                             "history": [{"dir", "message", "persona"}], "commit": {"message", "persona"},
                             "cheats": [name]}
    <root>/workspace/**     the broken workspace (final commit; the only commit when there is no history)
    <root>/history/<dir>/** earlier commits, applied cumulatively before workspace/
    <root>/solution/**      files of the reference fix (must include a test matching test_globs)
    <root>/cheats/<name>/** one overlay per listed cheat (each must still fail grading)
    <root>/grader/**        the grader bundle: grader.json (modes as in grader/run_grade.py; "baseline_commit" and
                            "protected" are filled in here) plus hidden tests

The recipe's ticket, hints and rubric blocks still apply (the rubric block extends scenario.json's rubric).
"""
from __future__ import annotations

import json
import os
import tempfile

from . import archive, docs, grader, history, overlays
from .errors import BuildError
from .inputs import Blocks
from .tree import Tree, block_subtree, overlay, read_block_file

SCENARIO_FILE = "scenario.json"
INITIAL_MESSAGE = "Initial commit"
LANGUAGES = ("python", "js", "fullstack")


def _scenario(blocks: Blocks, bdir: str, root: str) -> dict:
    try:
        sc = json.loads(read_block_file(blocks, bdir, f"{root}/{SCENARIO_FILE}"))
    except ValueError as exc:
        raise BuildError(f"custom scenario: {SCENARIO_FILE} is not valid JSON: {exc}") from exc
    if not isinstance(sc, dict) or not sc.get("root_cause_md") or not sc.get("ports"):
        raise BuildError(f"custom scenario: {SCENARIO_FILE} needs root_cause_md and ports")
    if sc.get("language", "python") not in LANGUAGES:
        raise BuildError(f"custom scenario: language must be one of {', '.join(LANGUAGES)}")
    return sc


def _app_view(sc: dict) -> dict:
    ports = sc["ports"]
    return {
        "language": sc.get("language", "python"), "setup": sc.get("setup", []), "ports": ports,
        "protected": sc.get("protected", []), "test_globs": sc.get("test_globs") or ["tests/*"],
        "base_url": f"http://127.0.0.1:{ports[0]}", "readiness_path": sc.get("readiness_path", "/"),
    }


def build_custom_variant(v: dict, blocks: Blocks, out_dir: str) -> None:
    c = v["custom"]
    bdir, root = c["dir"], c["root"]
    sc = _scenario(blocks, bdir, root)
    app = _app_view(sc)
    view = {**v, "app": app, "data": [], "stubs": [], "envs": [], "faults": []}

    workspace = block_subtree(blocks, bdir, f"{root}/workspace")
    if not workspace:
        raise BuildError(f"custom scenario: {root}/workspace/ is empty or missing")
    solution = block_subtree(blocks, bdir, f"{root}/solution")
    if not solution:
        raise BuildError(f"custom scenario: {root}/solution/ is empty or missing")
    steps = sc.get("history", [])
    dates = history.commit_dates(v["seed"], len(steps) + 1)

    with tempfile.TemporaryDirectory(prefix="mf-ws-") as work:
        ws = os.path.join(work, "ws")
        repo = history.Repo(ws)
        repo.init()
        tree: Tree = {}
        pre_fault = ""
        for i, step in enumerate(steps):
            sub = block_subtree(blocks, bdir, f"{root}/history/{step['dir']}")
            if not sub:
                raise BuildError(f"custom scenario: history/{step['dir']}/ is empty or missing")
            tree = overlay(tree, sub)
            pre_fault = repo.commit(tree, step["message"], step.get("persona"), dates[i])
        base_tree = overlay(tree, workspace)
        final = sc.get("commit") or {}
        message = final.get("message", INITIAL_MESSAGE) if steps else INITIAL_MESSAGE
        baseline_commit = repo.commit(base_tree, message, final.get("persona"), dates[-1])

        extras = docs.build_extras(view, blocks, docs.setup_commands(view))
        repo.exclude(docs.exclude_patterns(extras))
        for path, data in extras.items():
            full = os.path.join(ws, path)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "wb") as fh:
                fh.write(data)
            os.chmod(full, 0o755 if archive.is_exec(path, data) else 0o644)
        if not repo.is_clean():
            raise BuildError("workspace has uncommitted changes after the history was built")
        workspace_tgz = archive.tgz_from_dir(ws)

    protected = grader.protected_manifest(view, {**base_tree, **extras})
    grader_files = block_subtree(blocks, bdir, f"{root}/grader")
    try:
        conf = json.loads(grader_files["grader.json"])
    except (KeyError, ValueError) as exc:
        raise BuildError(f"custom scenario: {root}/grader/grader.json is missing or invalid") from exc
    conf["baseline_commit"], conf["protected"] = baseline_commit, protected
    conf.setdefault("app", {"base_url": app["base_url"], "readiness_path": app["readiness_path"], "readiness_timeout": 40})
    grader_files["grader.json"] = (json.dumps(conf, indent=2, sort_keys=True) + "\n").encode()
    grader_tgz = archive.tgz_from_files(grader_files)

    fixed = overlay(base_tree, solution)
    cheat_names = sc.get("cheats", [])
    verify_files: Tree = {"overlays/fix-1.tgz": overlays.overlay_tgz(base_tree, fixed)}
    cheats_meta = []
    for j, name in enumerate(cheat_names):
        sub = block_subtree(blocks, bdir, f"{root}/cheats/{name}")
        if not sub:
            raise BuildError(f"custom scenario: cheats/{name}/ is empty or missing")
        cheat_tree = overlay(base_tree, sub)
        verify_files[f"overlays/cheat-0-{j}.tgz"] = overlays.overlay_tgz(base_tree, cheat_tree)
        cheats_meta.append({"issue": 0, "name": name, "overlay": f"cheat:0:{j}",
                            "diff": overlays.unified_diff(base_tree, cheat_tree)})
    verify_tgz = archive.tgz_from_files(verify_files)

    own = sc.get("rubric") or {}
    rubric = {k: list(own.get(k, [])) + list(v["rubric"].get(k) or []) for k in ("key_points", "misconceptions")}
    meta = {
        "variant_key": v["key"], "baseline_commit": baseline_commit, "pre_fault_commit": pre_fault,
        "protected_manifest": protected, "app_ports": app["ports"], "brief_md": v["ticket_md"], "captures": v["captures"],
        "cheats": cheats_meta, "issues": 1,
        "sizes": {"workspace": len(workspace_tgz), "grader": len(grader_tgz), "verify": len(verify_tgz)},
        "payload": {
            "root_cause_md": sc["root_cause_md"], "fix_diff": overlays.unified_diff(base_tree, fixed), "rubric": rubric,
            "hint_ladder": v["hint_ladder"], "baseline_commit": baseline_commit, "pre_fault_commit": pre_fault,
            "issue_info": [{"label": sc.get("title", "custom"), "masked": False, "cheats": cheat_names}],
        },
    }
    os.makedirs(out_dir, exist_ok=True)
    for name, data in (("workspace.tar.gz", workspace_tgz), ("grader.tar.gz", grader_tgz), ("verify.tar.gz", verify_tgz),
                       ("meta.json", (json.dumps(meta, indent=2, sort_keys=True) + "\n").encode())):
        with open(os.path.join(out_dir, name), "wb") as fh:
            fh.write(data)
