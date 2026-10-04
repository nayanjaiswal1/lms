"""In-memory source trees, override layers, and materialization.

A *raw* tree is the app's source with slot markers still in it. A *layer* is
one override set (a fault's inject / carrier / fix, an env overlay, a cheat).
`materialize(raw, layers)` produces the tree a student (or a grader) sees:
layered file ops, slot values resolved, migrations inserted, every marker
stripped, sources formatted. Because the raw tree is kept separate, a later
history commit that rewrites a slotted file cannot silently undo an active
fault: the layers are simply re-applied on every materialization.
"""
from __future__ import annotations

import posixpath
from dataclasses import dataclass, field

from . import migrations
from .errors import BuildError
from .formatting import format_tree
from .inputs import Blocks, safe_relpath
from .slots import LEFTOVER, apply_text

Tree = dict[str, bytes]


@dataclass
class Layer:
    label: str
    files: list[tuple[str, bytes]] = field(default_factory=list)
    values: dict[str, str] = field(default_factory=dict)  # region/value slot overrides
    migrations: list[tuple[dict, bytes, str]] = field(default_factory=list)  # (decl, content, source name)


def read_block_file(blocks: Blocks, block_dir: str, rel: str) -> bytes:
    try:
        return blocks[block_dir][safe_relpath(rel)]
    except KeyError:
        raise BuildError(f"block file not found: {block_dir}/{rel}") from None


def block_subtree(blocks: Blocks, block_dir: str, prefix: str) -> Tree:
    """Files of a block payload under `prefix/`, keyed by the path below it."""
    want = prefix.strip("/") + "/"
    return {rel[len(want):]: data for rel, data in blocks.get(block_dir, {}).items() if rel.startswith(want)}


def layer_from(label: str, overrides: dict, blocks: Blocks, decls: dict[str, dict]) -> Layer:
    layer = Layer(label)
    block_dir = overrides["dir"]
    for op in overrides.get("files") or []:
        layer.files.append((safe_relpath(op["path"]), read_block_file(blocks, block_dir, op["from"])))
    for so in overrides.get("slots") or []:
        decl = decls.get(so["slot"])
        if decl is None:
            raise BuildError(f"{label}: overrides slot {so['slot']!r}, which the app does not declare")
        kind = decl["type"]
        data = read_block_file(blocks, block_dir, so["file"]) if so.get("file") else so.get("value", "").encode()
        if kind == "migration":
            if not so.get("file"):
                raise BuildError(f"{label}: migration slot {so['slot']!r} needs a file")
            layer.migrations.append((decl, data, so["file"]))
        elif kind == "file":
            layer.files.append((safe_relpath(decl["default"]), data))
        else:
            layer.values[so["slot"]] = data.decode("utf-8")
    return layer


def is_text(data: bytes) -> bool:
    return b"\x00" not in data[:8192]


def materialize(raw: Tree, layers: list[Layer], decls: dict[str, dict], seed: str, strict: bool = True) -> Tree:
    tree = dict(raw)
    values: dict[str, str] = {}
    for layer in layers:
        for path, data in layer.files:
            tree[path] = data
        values.update(layer.values)

    seen: dict[str, str] = {}
    for path in sorted(tree):
        data = tree[path]
        if b"mf:" not in data or not is_text(data):
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        tree[path] = apply_text(path, text, values, decls, seen).encode("utf-8")
    if strict:
        missing = sorted(set(values) - set(seen))
        if missing:
            raise BuildError(f"slot override(s) {missing} match no slot marker in the app source")

    for layer in layers:
        for decl, data, source in layer.migrations:
            migrations.insert(tree, decl, data, source, seed)

    if strict:
        assert_no_markers(tree)
    return format_tree(tree)


def assert_no_markers(tree: Tree) -> None:
    """Hard failure if any slot marker survived rendering: students must never see them."""
    for path in sorted(tree):
        data = tree[path]
        if not is_text(data):
            continue
        m = LEFTOVER.search(data.decode("utf-8", "replace"))
        if m:
            raise BuildError(f"{path}: an unresolved mf: marker remains after rendering ({m.group(0)!r})")


def overlay(base: Tree, extra: Tree) -> Tree:
    out = dict(base)
    out.update(extra)
    return out


def safe_key(key: str) -> str:
    return "".join(c if c.isalnum() or c in "._-" else "_" for c in key)


def parent_dirs(path: str) -> list[str]:
    parts = posixpath.dirname(path).split("/") if posixpath.dirname(path) else []
    return ["/".join(parts[: i + 1]) for i in range(len(parts))]
