"""Shared helpers for the probe kinds.

Probes are GENERIC: every kind is parameterised by the JSON a grader bundle
supplies, so a scenario block only passes params — it never ships probe code.
Failure messages are author-written strings from the bundle; nothing here ever
includes test source, expected values or server output in a message.
"""
from __future__ import annotations

import http.client
import json
import random
import re
import subprocess
import time
import urllib.parse
from dataclasses import dataclass, field
from typing import Any


class ProbeFailure(Exception):
    """An assertion failed. str(exc) is the author-facing reason (may be empty,
    in which case the probe's configured message is used)."""


@dataclass
class Context:
    base_url: str
    seed: str
    db_name: str
    db_url: str
    workdir: str
    grader_dir: str
    tmp_dir: str
    env: dict[str, str] = field(default_factory=dict)

    def rng(self, name: str) -> random.Random:
        """Deterministic per-(seed, probe) randomness: randomised per Check
        (the seed is server-random), reproducible within one Check."""
        return random.Random(f"{self.seed}:{name}")


_TEMPLATE = re.compile(r"\{\{(\w+)(?::([^}]*))?\}\}")


def _one_token(name: str, arg: str | None, rng: random.Random, extra: dict[str, Any]) -> Any:
    if name in extra:
        return extra[name]
    if name == "int":
        lo, hi = (int(x) for x in (arg or "0:100").split(":"))
        return rng.randint(lo, hi)
    if name == "rand_str":
        return "".join(rng.choice("abcdefghijklmnopqrstuvwxyz") for _ in range(int(arg or 8)))
    if name == "rand_hex":
        return "".join(rng.choice("0123456789abcdef") for _ in range(int(arg or 8)))
    if name == "choice":
        return rng.choice((arg or "").split("|"))
    raise ProbeFailure(f"unknown template token {name}")


def render(value: Any, rng: random.Random, extra: dict[str, Any] | None = None) -> Any:
    """Recursively expand {{int:a:b}}, {{rand_str:n}}, {{rand_hex:n}},
    {{choice:a|b}} and any {{name}} supplied in `extra` (e.g. seed, db).
    A string that is exactly one token keeps the token's native type."""
    extra = extra or {}
    if isinstance(value, str):
        whole = _TEMPLATE.fullmatch(value)
        if whole:
            return _one_token(whole.group(1), whole.group(2), rng, extra)
        return _TEMPLATE.sub(lambda m: str(_one_token(m.group(1), m.group(2), rng, extra)), value)
    if isinstance(value, list):
        return [render(v, rng, extra) for v in value]
    if isinstance(value, dict):
        return {k: render(v, rng, extra) for k, v in value.items()}
    return value


class Resp:
    def __init__(self, status: int, headers: list[tuple[str, str]], body: bytes, elapsed: float):
        self.status = status
        self.raw_headers = headers
        self.headers = {k.lower(): v for k, v in headers}
        self.body = body
        self.elapsed = elapsed

    @property
    def text(self) -> str:
        return self.body.decode("utf-8", "replace")

    def json(self) -> Any:
        try:
            return json.loads(self.text)
        except ValueError as exc:
            raise ProbeFailure("response was not valid JSON") from exc

    def set_cookies(self) -> list[str]:
        return [v for k, v in self.raw_headers if k.lower() == "set-cookie"]


def http_request(
    ctx: Context,
    method: str,
    path: str,
    headers: dict[str, str] | None = None,
    body: Any = None,
    timeout: float = 10.0,
    jar: dict[str, str] | None = None,
) -> Resp:
    """One HTTP request against the live, freshly restarted app. `jar` is a
    simple cookie jar (name -> value) updated from Set-Cookie."""
    parsed = urllib.parse.urlsplit(ctx.base_url)
    conn = http.client.HTTPConnection(parsed.hostname, parsed.port or 80, timeout=timeout)
    hdrs = dict(headers or {})
    payload: bytes | None = None
    if body is not None:
        if isinstance(body, (dict, list)):
            payload = json.dumps(body).encode()
            hdrs.setdefault("Content-Type", "application/json")
        elif isinstance(body, str):
            payload = body.encode()
        else:
            payload = bytes(body)
    if jar:
        hdrs["Cookie"] = "; ".join(f"{k}={v}" for k, v in jar.items())
    started = time.monotonic()
    try:
        conn.request(method.upper(), path, body=payload, headers=hdrs)
        r = conn.getresponse()
        data = r.read()
        resp = Resp(r.status, r.getheaders(), data, time.monotonic() - started)
    except (OSError, http.client.HTTPException) as exc:
        raise ProbeFailure("the application did not answer the request") from exc
    finally:
        conn.close()
    if jar is not None:
        for c in resp.set_cookies():
            pair = c.split(";", 1)[0]
            if "=" in pair:
                name, _, val = pair.partition("=")
                jar[name.strip()] = val.strip()
    return resp


def psql(ctx: Context, sql: str, db: str | None = None, timeout: int = 30) -> str:
    """Run SQL through psql against the grader database (or `db`) and return
    the unaligned output. Errors surface as ProbeFailure without server text."""
    proc = subprocess.run(
        ["psql", "-v", "ON_ERROR_STOP=1", "-tAX", "-h", "127.0.0.1", "-U", "labuser",
         "-d", db or ctx.db_name, "-c", sql],
        capture_output=True, text=True, timeout=timeout, check=False,
    )
    if proc.returncode != 0:
        raise ProbeFailure("a database check could not run")
    return proc.stdout.strip()


_PATH_TOKEN = re.compile(r"([^.\[\]]+)|\[(\d+)\]")


def jget(obj: Any, path: str) -> Any:
    """Read 'a.b[0].c' from parsed JSON; raises KeyError when absent."""
    cur = obj
    for m in _PATH_TOKEN.finditer(path):
        key, idx = m.group(1), m.group(2)
        if key is not None:
            if not isinstance(cur, dict) or key not in cur:
                raise KeyError(path)
            cur = cur[key]
        else:
            i = int(idx)
            if not isinstance(cur, list) or i >= len(cur):
                raise KeyError(path)
            cur = cur[i]
    return cur


def check_json(data: Any, expectations: list[dict[str, Any]]) -> None:
    """Assert JSON expectations: {path, equals|min|max|type|contains|regex|exists|length}."""
    for e in expectations:
        path = e["path"]
        try:
            val = jget(data, path)
        except KeyError:
            if e.get("exists") is False:
                continue
            raise ProbeFailure(e.get("message", "")) from None
        if e.get("exists") is False:
            raise ProbeFailure(e.get("message", ""))
        if "equals" in e and val != e["equals"]:
            raise ProbeFailure(e.get("message", ""))
        if "min" in e and not (isinstance(val, (int, float)) and val >= e["min"]):
            raise ProbeFailure(e.get("message", ""))
        if "max" in e and not (isinstance(val, (int, float)) and val <= e["max"]):
            raise ProbeFailure(e.get("message", ""))
        if "length" in e and not (hasattr(val, "__len__") and len(val) == e["length"]):
            raise ProbeFailure(e.get("message", ""))
        if "contains" in e and not (hasattr(val, "__contains__") and e["contains"] in val):
            raise ProbeFailure(e.get("message", ""))
        if "regex" in e and not re.search(e["regex"], str(val)):
            raise ProbeFailure(e.get("message", ""))
        if "type" in e:
            names = {"string": str, "number": (int, float), "integer": int, "boolean": bool,
                     "array": list, "object": dict, "null": type(None)}
            want = names.get(e["type"])
            if want is None or isinstance(val, bool) and e["type"] in ("number", "integer") \
                    or not isinstance(val, want):
                raise ProbeFailure(e.get("message", ""))


def status_ok(status: int, expected: Any) -> bool:
    if expected is None:
        return 200 <= status < 300
    if isinstance(expected, list):
        return status in expected
    return status == expected


def run_command(ctx: Context, cmd: str, cwd: str | None = None, extra_env: dict[str, str] | None = None,
                timeout: int = 60) -> subprocess.CompletedProcess:
    """Run a shell command from a grader bundle in the workspace with the
    grader's environment. Output is captured and never shown to the student."""
    import os

    env = dict(os.environ)
    env.update(ctx.env)
    env.update(extra_env or {})
    return subprocess.run(["bash", "-c", cmd], cwd=cwd or ctx.workdir, env=env, capture_output=True,
                          text=True, timeout=timeout, check=False)
