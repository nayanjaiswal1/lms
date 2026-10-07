"""Slot markers (docs/debug-labs.md B2): region and value slots.

Region slots are comment-delimited blocks that stay valid source before
rendering:

    # mf:slot orders.list.queryset          (also //, <!-- --> and, inside JSX, {/* ... */})
    orders = Order.objects.select_related("customer")
    # mf:endslot

Value slots replace a scalar in place:

    USE_TZ = @@mf:value settings.use_tz=True@@

An override replaces the region body (re-indented to the marker) or the value;
without one the default (the text between the markers) is kept. Every marker is
stripped; leftovers are a hard error (see tree.assert_no_markers).
"""
from __future__ import annotations

import re
import textwrap

from .errors import BuildError

REGION_START = re.compile(
    r"^(?P<indent>[ \t]*)\{?\s*(?:#|//|<!--|/\*)\s*mf:slot\s+(?P<name>[\w.\-]+)\s*(?:-->|\*/)?\s*\}?\s*$")
REGION_END = re.compile(r"^[ \t]*\{?\s*(?:#|//|<!--|/\*)\s*mf:endslot\s*(?:-->|\*/)?\s*\}?\s*$")
VALUE = re.compile(r"@@mf:value\s+(?P<name>[\w.\-]+)=(?P<default>.*?)@@")
LEFTOVER = re.compile(r"mf:(?:slot|endslot|value)\b|@@mf:")


def reindent(body: str, indent: str) -> list[str]:
    body = textwrap.dedent(body.strip("\n"))
    if not body.strip():
        return []
    return [(indent + line) if line.strip() else "" for line in body.split("\n")]


def apply_text(path: str, text: str, values: dict[str, str], decls: dict[str, dict], seen: dict[str, str]) -> str:
    """Resolve every slot marker in one file. `seen` maps slot name -> path of
    its (single) definition and is shared across the whole tree."""

    def claim(name: str) -> None:
        if name in seen:
            raise BuildError(f"slot {name!r} is defined twice ({seen[name]} and {path})")
        seen[name] = path

    def check_type(name: str, want: str) -> None:
        decl = decls.get(name)
        if decl is None:
            raise BuildError(f"{path}: slot {name!r} is not declared in the app's slot catalog")
        if decl["type"] != want:
            raise BuildError(f"{path}: slot {name!r} is a {decl['type']} slot but is marked as {want}")

    out: list[str] = []
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        m = REGION_START.match(lines[i])
        if not m:
            out.append(lines[i])
            i += 1
            continue
        name = m.group("name")
        check_type(name, "region")
        claim(name)
        j = i + 1
        while j < len(lines) and not REGION_END.match(lines[j]):
            if REGION_START.match(lines[j]):
                raise BuildError(f"{path}: slot {name!r} contains a nested slot")
            j += 1
        if j >= len(lines):
            raise BuildError(f"{path}: slot {name!r} has no mf:endslot")
        if name in values:
            out.extend(reindent(values[name], m.group("indent")))
        else:
            out.extend(lines[i + 1:j])
        i = j + 1
    result = "\n".join(out)

    def value_sub(m: re.Match) -> str:
        name = m.group("name")
        check_type(name, "value")
        claim(name)
        return values[name].strip() if name in values else m.group("default")

    return VALUE.sub(value_sub, result)
