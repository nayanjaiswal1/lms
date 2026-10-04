"""Kind C — N concurrent requests, then an invariant checked in the database.

params:
  before_sql:   [sql]                 reset/seed state (templates allowed)
  request:      {method, path, body?, headers?}
  count:        total requests (default 20)
  workers:      concurrency (default = count)
  allowed_status: [200, 201, 409]     statuses that are not failures (default 2xx/4xx)
  invariant:    {sql, equals? | min? | max?}   scalar result of the SQL
  expect_successes: {min?, max?}      how many requests may/must succeed (2xx)
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from typing import Any

from .common import Context, ProbeFailure, http_request, psql, render

KIND = "C"


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    rng = ctx.rng(name)
    extra = {"seed": ctx.seed}
    for sql in params.get("before_sql", []):
        psql(ctx, render(sql, rng, extra))

    req = render(params["request"], rng, extra)
    count = int(params.get("count", 20))
    workers = int(params.get("workers", count))

    def one(_: int) -> int:
        try:
            return http_request(ctx, req.get("method", "POST"), req["path"], req.get("headers"),
                                req.get("body"), timeout=float(params.get("timeout", 30))).status
        except ProbeFailure:
            return 0

    with ThreadPoolExecutor(max_workers=workers) as pool:
        statuses = list(pool.map(one, range(count)))

    allowed = params.get("allowed_status")
    for s in statuses:
        if s == 0 or s >= 500 or (allowed is not None and s not in allowed):
            raise ProbeFailure("")
    successes = sum(1 for s in statuses if 200 <= s < 300)
    want = params.get("expect_successes", {})
    if ("min" in want and successes < want["min"]) or ("max" in want and successes > want["max"]):
        raise ProbeFailure("")

    inv = params.get("invariant")
    if inv:
        raw = psql(ctx, render(inv["sql"], rng, extra))
        try:
            val: Any = float(raw)
        except ValueError:
            val = raw
        if "equals" in inv and val != inv["equals"]:
            raise ProbeFailure("")
        if "min" in inv and not (isinstance(val, float) and val >= inv["min"]):
            raise ProbeFailure("")
        if "max" in inv and not (isinstance(val, float) and val <= inv["max"]):
            raise ProbeFailure("")
