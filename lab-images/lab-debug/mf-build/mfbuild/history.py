"""Deterministic git history (docs/debug-labs.md B2 "Git history").

Timeline: scaffold -> feature commits -> fault commit(s) (slot changes plus the
carrier feature) -> noise commits. Dates derive from the recipe seed, authors
from the app/fault personas, and every commit builds because each one is a full
materialization of raw source + active override layers.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import os
import re
import shutil
import subprocess

from .archive import is_exec
from .errors import BuildError
from .tree import Tree

DEFAULT_PERSONA = "Dev Team <dev@shop.example>"
SCAFFOLD_MESSAGE = "Initial commit"
PERSONA_RE = re.compile(r"^\s*(?P<name>.+?)\s*<(?P<email>[^<>@\s]+@[^<>\s]+)>\s*$")
BASE_DATE = dt.datetime(2025, 1, 6, 9, 0, 0, tzinfo=dt.timezone.utc)
MIN_STEP_SECONDS = 6 * 3600
JITTER_SECONDS = 40 * 3600
GIT_TIMEOUT = 60
DEFAULT_LATE_WINDOW = (2, 4)  # the fault commit lands between the last 2-4 features


def parse_persona(persona: str | None) -> tuple[str, str]:
    m = PERSONA_RE.match(persona or DEFAULT_PERSONA)
    if not m:
        raise BuildError(f"persona {persona!r} must look like 'Name <email@host>'")
    return m.group("name"), m.group("email")


def commit_dates(seed: int, count: int) -> list[str]:
    when = BASE_DATE + dt.timedelta(days=seed % 90)
    out = []
    for i in range(count):
        jitter = int(hashlib.sha256(f"{seed}:{i}".encode()).hexdigest()[:8], 16) % JITTER_SECONDS
        when += dt.timedelta(seconds=MIN_STEP_SECONDS + jitter)
        out.append(when.strftime("%Y-%m-%dT%H:%M:%S+0000"))
    return out


def fault_position(position: str | None, features: int, seed: int) -> int:
    """Index into the feature list at which the fault commit is inserted."""
    if position == "end":
        return features
    if position == "early":
        return min(1, features)
    lo, hi = DEFAULT_LATE_WINDOW
    back = lo + seed % (hi - lo + 1)
    return max(0, features - back)


def plan(spec: dict) -> list[dict]:
    """Ordered commit plan. Steps: scaffold | feature(h) | fault(i) | noise(n)."""
    seed = spec["seed"]
    history = spec["app"]["history"]
    faults = spec["faults"]
    pos = fault_position(faults[0]["commit"].get("position") if faults else None, len(history), seed)
    steps: list[dict] = [{"kind": "scaffold", "message": SCAFFOLD_MESSAGE, "persona": None}]
    for idx, h in enumerate(history):
        if idx == pos:
            steps += [{"kind": "fault", "index": i} for i in range(len(faults))]
        steps.append({"kind": "feature", "commit": h})
    if pos >= len(history):
        steps += [{"kind": "fault", "index": i} for i in range(len(faults))]
    for n in spec["app"]["noise"]:
        steps.append({"kind": "noise", "commit": n})
    return steps


class Repo:
    def __init__(self, root: str) -> None:
        self.root = root

    def git(self, *args: str, env: dict | None = None) -> str:
        full_env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "HOME": self.root, "GIT_TERMINAL_PROMPT": "0", **(env or {})}
        proc = subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "commit.gpgsign=false", "-c", "gc.auto=0", *args],
                              cwd=self.root, env=full_env, capture_output=True, text=True, timeout=GIT_TIMEOUT, check=False)
        if proc.returncode != 0:
            raise BuildError(f"git {' '.join(args[:2])} failed: {proc.stderr.strip()[-800:]}")
        return proc.stdout.strip()

    def init(self) -> None:
        os.makedirs(self.root, exist_ok=True)
        self.git("init", "-q", "-b", "main")
        hooks = os.path.join(self.root, ".git", "hooks")
        shutil.rmtree(hooks, ignore_errors=True)

    def write_tree(self, tree: Tree) -> None:
        """Make the working directory exactly `tree` (leaving .git alone)."""
        for cur, dirs, files in os.walk(self.root):
            dirs[:] = [d for d in dirs if d != ".git"]
            for name in files:
                full = os.path.join(cur, name)
                rel = os.path.relpath(full, self.root).replace(os.sep, "/")
                if rel not in tree:
                    os.remove(full)
        for rel, data in tree.items():
            full = os.path.join(self.root, rel)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "wb") as fh:
                fh.write(data)
            os.chmod(full, 0o755 if is_exec(rel, data) else 0o644)
        for cur, dirs, files in os.walk(self.root, topdown=False):
            if cur != self.root and ".git" not in cur.split(os.sep) and not dirs and not files:
                os.rmdir(cur)

    def commit(self, tree: Tree, message: str, persona: str | None, when: str) -> str:
        self.write_tree(tree)
        self.git("add", "-A")
        if not self.git("status", "--porcelain"):
            raise BuildError(f"commit {message!r} changes nothing")
        name, email = parse_persona(persona)
        env = {"GIT_AUTHOR_NAME": name, "GIT_AUTHOR_EMAIL": email, "GIT_AUTHOR_DATE": when,
               "GIT_COMMITTER_NAME": name, "GIT_COMMITTER_EMAIL": email, "GIT_COMMITTER_DATE": when}
        self.git("commit", "-q", "-m", message, env=env)
        return self.git("rev-parse", "HEAD")

    def exclude(self, patterns: list[str]) -> None:
        info = os.path.join(self.root, ".git", "info")
        os.makedirs(info, exist_ok=True)
        with open(os.path.join(info, "exclude"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(patterns) + "\n")

    def is_clean(self) -> bool:
        return self.git("status", "--porcelain") == ""
