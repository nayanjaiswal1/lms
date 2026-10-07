"""Builds one variant: history + workspace, grader bundle, verification
overlays and meta.json (the artifacts the platform stores and verifies)."""
from __future__ import annotations

import json
import os
import tempfile

from . import archive, docs, grader, history, overlays
from .custom import build_custom_variant
from .errors import BuildError
from .inputs import Blocks
from .tree import Layer, Tree, block_subtree, layer_from, materialize, overlay


def _decls(v: dict) -> dict[str, dict]:
    return {s["name"]: s for s in v["app"]["slots"]}


def _overlay_dirs(blocks: Blocks, app_dir: str, kind: str, commit: dict) -> Tree:
    """Files of a history/noise commit: the union of its named overlay dirs."""
    out: Tree = {}
    paths = commit.get("paths") or []
    if not paths:
        raise BuildError(f"{kind} commit {commit.get('message')!r} lists no paths")
    for name in paths:
        sub = block_subtree(blocks, app_dir, f"{kind}/{name}")
        if not sub:
            raise BuildError(f"{kind} commit {commit.get('message')!r}: {kind}/{name}/ is empty or missing in the app")
        out.update(sub)
    return out


def _fault_layers(v: dict, blocks: Blocks, decls: dict) -> list[dict]:
    out = []
    for i, f in enumerate(v["faults"]):
        out.append({
            "inject": layer_from(f"fault {f['key']} inject", f["inject"], blocks, decls),
            "carrier": layer_from(f"fault {f['key']} carrier", f["carrier"]["overrides"], blocks, decls),
            "fix": layer_from(f"fault {f['key']} fix", f["fix"], blocks, decls),
            "cheats": [(c["name"], layer_from(f"fault {f['key']} cheat {c['name']}", c["overrides"], blocks, decls))
                       for c in f["cheats"]],
        })
    return out


def build_variant(v: dict, blocks: Blocks, out_dir: str) -> None:
    if v.get("custom"):
        build_custom_variant(v, blocks, out_dir)
        return
    app = v["app"]
    decls = _decls(v)
    seed = v["seed_hex"]
    if not v["faults"]:
        raise BuildError("variant has no faults")

    raw: Tree = block_subtree(blocks, app["dir"], "src")
    if not raw:
        raise BuildError(f"app {app['key']} has no src/ scaffold")
    faults = _fault_layers(v, blocks, decls)
    env_layers = [layer_from(f"env {e['key']}", {"dir": e["dir"], "files": e["overlay"], "slots": []}, blocks, decls)
                  for e in v["envs"]]

    steps = history.plan(v)
    dates = history.commit_dates(v["seed"], len(steps))
    active: list[Layer] = []
    pre_fault_commit = ""
    head = ""

    with tempfile.TemporaryDirectory(prefix="mf-ws-") as work:
        ws = os.path.join(work, "ws")
        repo = history.Repo(ws)
        repo.init()
        tree: Tree = {}
        for idx, step in enumerate(steps):
            last = idx == len(steps) - 1
            kind = step["kind"]
            if kind == "scaffold":
                message, persona = step["message"], step["persona"]
            elif kind == "feature":
                raw = overlay(raw, _overlay_dirs(blocks, app["dir"], "history", step["commit"]))
                message, persona = step["commit"]["message"], step["commit"].get("persona")
            elif kind == "noise":
                raw = overlay(raw, _overlay_dirs(blocks, app["dir"], "noise", step["commit"]))
                message, persona = step["commit"]["message"], step["commit"].get("persona")
            else:  # fault
                if not pre_fault_commit:
                    pre_fault_commit = head
                    active += env_layers
                i = step["index"]
                active += [faults[i]["inject"], faults[i]["carrier"]]
                commit = v["faults"][i]["commit"]
                message, persona = commit["message"], commit.get("persona")
            tree = materialize(raw, active, decls, seed, strict=last)
            head = repo.commit(tree, message, persona, dates[idx])
        base_tree = tree
        baseline_commit = head

        extras = docs.build_extras(v, blocks, docs.setup_commands(v))
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

    protected = grader.protected_manifest(v, {**base_tree, **extras})
    grader_files = grader.build_grader(v, blocks, docs.setup_commands(v), protected, baseline_commit)
    grader_tgz = archive.tgz_from_files(grader_files)

    # Verification overlays: the fix of the first n issues, and each cheat.
    verify_files: Tree = {}
    fix_layers: list[Layer] = []
    for n, f in enumerate(faults, start=1):
        fix_layers.append(f["fix"])
        fixed = materialize(raw, active + fix_layers, decls, seed)
        verify_files[f"overlays/fix-{n}.tgz"] = overlays.overlay_tgz(base_tree, fixed)
        if n == len(faults):
            full_fix_tree = fixed
    cheats_meta = []
    for i, f in enumerate(faults):
        for j, (name, layer) in enumerate(f["cheats"]):
            cheat_tree = materialize(raw, active + [layer], decls, seed)
            verify_files[f"overlays/cheat-{i}-{j}.tgz"] = overlays.overlay_tgz(base_tree, cheat_tree)
            cheats_meta.append({"issue": i, "name": name, "overlay": f"cheat:{i}:{j}",
                                "diff": overlays.unified_diff(base_tree, cheat_tree)})
    fix_diff = overlays.unified_diff(base_tree, full_fix_tree)
    verify_tgz = archive.tgz_from_files(verify_files)

    meta = {
        "variant_key": v["key"],
        "baseline_commit": baseline_commit,
        "pre_fault_commit": pre_fault_commit,
        "protected_manifest": protected,
        "app_ports": app["ports"],
        "brief_md": v["ticket_md"],
        "captures": v["captures"],
        "cheats": cheats_meta,
        "issues": len(faults),
        "sizes": {"workspace": len(workspace_tgz), "grader": len(grader_tgz), "verify": len(verify_tgz)},
        "payload": {
            "root_cause_md": v["root_cause_md"], "fix_diff": fix_diff, "rubric": v["rubric"],
            "hint_ladder": v["hint_ladder"], "baseline_commit": baseline_commit, "pre_fault_commit": pre_fault_commit,
            "issue_info": [
                {"label": f["key"], "masked": bool(f.get("chain") and f["chain"].get("mode") == "masks"),
                 "cheats": [c["name"] for c in f["cheats"]]}
                for f in v["faults"]
            ],
        },
    }
    os.makedirs(out_dir, exist_ok=True)
    for name, data in (("workspace.tar.gz", workspace_tgz), ("grader.tar.gz", grader_tgz), ("verify.tar.gz", verify_tgz),
                       ("meta.json", (json.dumps(meta, indent=2, sort_keys=True) + "\n").encode())):
        with open(os.path.join(out_dir, name), "wb") as fh:
            fh.write(data)
