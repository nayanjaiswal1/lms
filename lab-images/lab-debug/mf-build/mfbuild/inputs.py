"""Reads the input tar into the render spec and per-block payload files."""
from __future__ import annotations

import json
import posixpath
import tarfile
from typing import BinaryIO

from .errors import BuildError

MAX_TOTAL_BYTES = 96 * 1024 * 1024
MAX_FILE_BYTES = 8 * 1024 * 1024
SPEC_NAME = "spec.json"
BLOCKS_PREFIX = "blocks/"

# blocks[dir][relpath] -> bytes
Blocks = dict[str, dict[str, bytes]]


def safe_relpath(name: str) -> str:
    norm = posixpath.normpath(name)
    if norm.startswith("/") or norm == ".." or norm.startswith("../") or norm == ".":
        raise BuildError(f"unsafe path in input: {name!r}")
    return norm


def read_input(stream: BinaryIO) -> tuple[dict, Blocks]:
    spec: dict | None = None
    blocks: Blocks = {}
    total = 0
    try:
        with tarfile.open(fileobj=stream, mode="r|*") as tar:
            for member in tar:
                if member.isdir():
                    continue
                if not member.isreg():
                    raise BuildError(f"input contains a non-regular entry: {member.name!r}")
                if member.size > MAX_FILE_BYTES:
                    raise BuildError(f"input file too large: {member.name!r}")
                total += member.size
                if total > MAX_TOTAL_BYTES:
                    raise BuildError("input tar exceeds the size cap")
                data = tar.extractfile(member).read()  # type: ignore[union-attr]
                name = safe_relpath(member.name)
                if name == SPEC_NAME:
                    spec = json.loads(data)
                elif name.startswith(BLOCKS_PREFIX):
                    rest = name[len(BLOCKS_PREFIX):]
                    block_dir, _, rel = rest.partition("/")
                    if not rel:
                        raise BuildError(f"input file outside a block dir: {name!r}")
                    blocks.setdefault(block_dir, {})[rel] = data
                else:
                    raise BuildError(f"unexpected input entry: {name!r}")
    except (tarfile.TarError, ValueError) as exc:
        raise BuildError(f"unreadable input: {exc}") from exc
    if spec is None or spec.get("schema") != 1 or not spec.get("variants"):
        raise BuildError("input has no valid spec.json (schema 1)")
    return spec, blocks
