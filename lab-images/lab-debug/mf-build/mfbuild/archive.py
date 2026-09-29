"""Deterministic tar.gz writers (sorted entries, zeroed ownership, fixed mtime)."""
from __future__ import annotations

import gzip
import io
import os
import stat
import tarfile

from .errors import BuildError

# Fixed entry mtime (2025-01-01T00:00:00Z): not 1970, which some tools treat as "never built".
FIXED_MTIME = 1735689600


def is_exec(path: str, data: bytes) -> bool:
    return data.startswith(b"#!") or path.endswith(".sh")


def _open(buf: io.BytesIO) -> tuple[gzip.GzipFile, tarfile.TarFile]:
    gz = gzip.GzipFile(fileobj=buf, mode="wb", mtime=0, compresslevel=9)
    return gz, tarfile.open(fileobj=gz, mode="w", format=tarfile.PAX_FORMAT)


def _info(name: str, size: int, mode: int, is_dir: bool = False) -> tarfile.TarInfo:
    ti = tarfile.TarInfo(name)
    ti.size = 0 if is_dir else size
    ti.mode = mode
    ti.type = tarfile.DIRTYPE if is_dir else tarfile.REGTYPE
    ti.mtime = FIXED_MTIME
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = ""
    return ti


def tgz_from_files(files: dict[str, bytes]) -> bytes:
    """Tar.gz of in-memory files (executable bit from shebang / .sh suffix)."""
    buf = io.BytesIO()
    gz, tar = _open(buf)
    for path in sorted(files):
        data = files[path]
        tar.addfile(_info(path, len(data), 0o755 if is_exec(path, data) else 0o644), io.BytesIO(data))
    tar.close()
    gz.close()
    return buf.getvalue()


def tgz_from_dir(root: str) -> bytes:
    """Tar.gz of a directory tree on disk, including directories (git needs its
    empty ones) and preserving the executable bit. Symlinks are refused."""
    buf = io.BytesIO()
    gz, tar = _open(buf)
    entries: list[str] = []
    for cur, dirs, files in os.walk(root):
        dirs.sort()
        rel = os.path.relpath(cur, root)
        if rel != ".":
            entries.append(rel.replace(os.sep, "/") + "/")
        for name in sorted(files):
            entries.append((name if rel == "." else rel.replace(os.sep, "/") + "/" + name))
    for entry in entries:
        full = os.path.join(root, entry.rstrip("/"))
        st = os.lstat(full)
        if stat.S_ISLNK(st.st_mode):
            raise BuildError(f"symlink in workspace: {entry}")
        if entry.endswith("/"):
            tar.addfile(_info(entry.rstrip("/"), 0, 0o755, is_dir=True))
            continue
        with open(full, "rb") as fh:
            data = fh.read()
        mode = 0o755 if st.st_mode & stat.S_IXUSR else 0o644
        tar.addfile(_info(entry, len(data), mode), io.BytesIO(data))
    tar.close()
    gz.close()
    return buf.getvalue()
