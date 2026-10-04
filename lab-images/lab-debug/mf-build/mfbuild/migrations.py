"""Migration slots: insert a fault's migration as the next one in the app's
migration directory, numbered and chained to the current head.

  django  <dir>/NNNN_<slug>.py, NNNN = highest existing number + 1; the file
          content may use {{mf.prev}} (previous migration stem) and {{mf.number}}.
  alembic <dir>/<rev>_<slug>.py, rev derived deterministically; the content
          may use {{mf.revision}} and {{mf.prev}} (the current head revision).
"""
from __future__ import annotations

import hashlib
import posixpath
import re

from .errors import BuildError

DJANGO_NAME = re.compile(r"^(\d{4})_(.+)\.py$")
ALEMBIC_REV = re.compile(r"^revision\s*(?::\s*[\w\[\], |]+)?=\s*[\"']([^\"']+)[\"']", re.M)
ALEMBIC_DOWN = re.compile(r"^down_revision\s*(?::\s*[\w\[\], |]+)?=\s*(None|[\"'][^\"']+[\"'])", re.M)


def slug_of(source_name: str) -> str:
    base = posixpath.basename(source_name)
    base = re.sub(r"\.py$", "", base)
    base = re.sub(r"^\d+_", "", base)
    slug = re.sub(r"[^a-z0-9_]+", "_", base.lower()).strip("_")
    return slug or "change"


def _fill(content: bytes, **fields: str) -> bytes:
    text = content.decode("utf-8")
    for key, val in fields.items():
        text = text.replace("{{mf." + key + "}}", val)
    if "{{mf." in text:
        raise BuildError("migration uses an unknown {{mf.*}} placeholder")
    return text.encode("utf-8")


def insert(tree: dict[str, bytes], decl: dict, content: bytes, source_name: str, seed: str) -> str:
    """Add the migration to `tree`; returns its path."""
    directory = decl["dir"].strip("/")
    scheme = decl["scheme"]
    slug = slug_of(source_name)
    names = {p: posixpath.basename(p) for p in tree if posixpath.dirname(p) == directory and p.endswith(".py")}
    if scheme == "django":
        numbered = sorted((int(m.group(1)), n[:-3]) for n in names.values() if (m := DJANGO_NAME.match(n)))
        if not numbered:
            raise BuildError(f"migration slot {decl['name']!r}: no existing migrations in {directory}")
        number, prev = numbered[-1][0] + 1, numbered[-1][1]
        path = f"{directory}/{number:04d}_{slug}.py"
        tree[path] = _fill(content, prev=prev, number=f"{number:04d}")
        return path
    if scheme == "alembic":
        revs, downs = set(), set()
        for p in names:
            text = tree[p].decode("utf-8", "replace")
            r, d = ALEMBIC_REV.search(text), ALEMBIC_DOWN.search(text)
            if r:
                revs.add(r.group(1))
            if d and d.group(1) != "None":
                downs.add(d.group(1).strip("\"'"))
        heads = sorted(revs - downs)
        if len(heads) != 1:
            raise BuildError(f"migration slot {decl['name']!r}: expected one alembic head in {directory}, found {heads}")
        rev = "mf" + hashlib.sha1(f"{heads[0]}:{slug}:{seed}".encode()).hexdigest()[:10]
        path = f"{directory}/{rev}_{slug}.py"
        tree[path] = _fill(content, revision=rev, prev=heads[0])
        return path
    raise BuildError(f"migration slot {decl['name']!r}: unknown scheme {scheme!r}")
