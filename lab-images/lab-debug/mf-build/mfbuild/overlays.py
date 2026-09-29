"""Overlays: the editable-file sets build verification applies on top of the
pristine (broken) workspace - the reference fix (per prefix of the chain) and
each cheat - plus their unified diffs (fix.diff for the debrief / hint leak
filter, one diff per cheat for the report)."""
from __future__ import annotations

import difflib

from .archive import tgz_from_files
from .tree import Tree, is_text


def changed_files(base: Tree, new: Tree) -> Tree:
    """Files added or modified in `new` relative to `base`."""
    return {p: d for p, d in new.items() if base.get(p) != d}


def unified_diff(base: Tree, new: Tree) -> str:
    chunks: list[str] = []
    for path in sorted(changed_files(base, new)):
        old, cur = base.get(path), new[path]
        if not is_text(cur) or (old is not None and not is_text(old)):
            chunks.append(f"Binary file {path} differs\n")
            continue
        header = [f"diff --git a/{path} b/{path}"]
        if old is None:
            header.append("new file mode 100644")
        a = old.decode("utf-8", "replace").splitlines() if old is not None else []
        b = cur.decode("utf-8", "replace").splitlines()
        body = difflib.unified_diff(a, b, fromfile=f"a/{path}" if old is not None else "/dev/null",
                                    tofile=f"b/{path}", lineterm="", n=3)
        chunks.append("\n".join(header + list(body)) + "\n")
    return "".join(chunks)


def overlay_tgz(base: Tree, new: Tree) -> bytes:
    return tgz_from_files(changed_files(base, new))
