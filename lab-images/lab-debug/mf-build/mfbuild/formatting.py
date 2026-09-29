"""Formats rendered source so slot regions look native (ruff format for
Python, prettier for JS/TS when the image has it)."""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile

from .errors import BuildError

PY_EXT = (".py",)
JS_EXT = (".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs")
TIMEOUT_SECONDS = 120


def _run(cmd: list[str], what: str) -> None:
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT_SECONDS, check=False)
    if proc.returncode != 0:
        raise BuildError(f"{what} failed (is the rendered source valid?):\n{(proc.stderr or proc.stdout)[-1500:]}")


def format_tree(tree: dict[str, bytes]) -> dict[str, bytes]:
    py = [p for p in tree if p.endswith(PY_EXT)]
    js = [p for p in tree if p.endswith(JS_EXT)]
    prettier = shutil.which("prettier") if js else None
    if not py and not (js and prettier):
        return tree
    todo = py + (js if prettier else [])
    out = dict(tree)
    with tempfile.TemporaryDirectory(prefix="mf-fmt-") as root:
        for p in todo:
            dest = os.path.join(root, p)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as fh:
                fh.write(tree[p])
        if py:
            _run(["ruff", "format", "--isolated", root], "ruff format")
        if js and prettier:
            _run([prettier, "--write", "--no-config", "--log-level", "warn", "--single-quote",
                  *[os.path.join(root, p) for p in js]], "prettier")
        for p in todo:
            with open(os.path.join(root, p), "rb") as fh:
                out[p] = fh.read()
    return out
