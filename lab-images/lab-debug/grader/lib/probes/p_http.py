"""Kind P — HTTP behavior against the live app.

params:
  steps: [ {method, path, headers?, body?, session?, expect_status?, expect_json?: [...] } ]
  (a single-step probe may put those keys directly in params)
`session` names an independent cookie jar, so one probe can act as two users.
Any string may use {{int:a:b}} / {{rand_str:n}} / {{seed}} templates, expanded
deterministically from the per-Check seed.
"""
from __future__ import annotations

from typing import Any

from .common import Context, ProbeFailure, check_json, http_request, render, status_ok

KIND = "P"


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    rng = ctx.rng(name)
    steps = params.get("steps") or [params]
    jars: dict[str, dict[str, str]] = {}
    saved: dict[str, Any] = {}
    for raw in steps:
        step = render(raw, rng, {"seed": ctx.seed, **saved})
        jar = jars.setdefault(step.get("session", "default"), {})
        resp = http_request(ctx, step.get("method", "GET"), step["path"], step.get("headers"),
                            step.get("body"), timeout=float(step.get("timeout", 10)), jar=jar)
        if not status_ok(resp.status, step.get("expect_status")):
            raise ProbeFailure(step.get("message", ""))
        if step.get("expect_json"):
            check_json(resp.json(), step["expect_json"])
        for var, path in (step.get("save") or {}).items():
            from .common import jget

            try:
                saved[var] = jget(resp.json(), path)
            except KeyError:
                raise ProbeFailure(step.get("message", "")) from None
