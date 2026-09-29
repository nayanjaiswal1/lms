"""Kind Q — query count / plan shape, measured with pg_stat_statements.

params:
  endpoint:      request path exercised (GET) — or `request: {method,path,body}`
  scales:        [n1, n2, ...] row counts; for each, `pre_sql` runs first with
                 {{scale}} substituted (seed extra rows), then the request runs
                 and the statements executed against the grader DB are counted
  pre_sql:       [sql, ...] (templates allowed, {{scale}} available)
  max_queries:   int — absolute ceiling per scale
  max_growth:    int — allowed growth of the count between the smallest and the
                 largest scale (default 0: the count must be constant in rows)
  explain:       [{sql, forbid: "Seq Scan", relation?: "table"}] — EXPLAIN (FORMAT JSON)
                 plans must not contain the forbidden node type
"""
from __future__ import annotations

import json
from typing import Any

from .common import Context, ProbeFailure, http_request, psql, render

KIND = "Q"

_COUNT_SQL = (
    "SELECT COALESCE(sum(calls),0)::bigint FROM pg_stat_statements "
    "WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database()) "
    "AND query NOT ILIKE '%pg_stat_statements%'"
)


def _has_node(plan: Any, node_type: str, relation: str | None) -> bool:
    if isinstance(plan, dict):
        if plan.get("Node Type") == node_type and (relation is None or plan.get("Relation Name") == relation):
            return True
        return any(_has_node(v, node_type, relation) for v in plan.values())
    if isinstance(plan, list):
        return any(_has_node(v, node_type, relation) for v in plan)
    return False


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    rng = ctx.rng(name)
    if psql(ctx, "SELECT count(*) FROM pg_extension WHERE extname='pg_stat_statements'") != "1":
        raise ProbeFailure("the query-count extension is not available")

    request = params.get("request") or {"method": "GET", "path": params.get("endpoint", "/")}
    counts: list[int] = []
    for scale in params.get("scales", [10]):
        for sql in params.get("pre_sql", []):
            psql(ctx, render(sql, rng, {"scale": scale, "seed": ctx.seed}))
        psql(ctx, "SELECT pg_stat_statements_reset()")
        req = render(request, rng, {"scale": scale, "seed": ctx.seed})
        resp = http_request(ctx, req.get("method", "GET"), req["path"], req.get("headers"), req.get("body"),
                            timeout=float(params.get("timeout", 30)))
        if resp.status >= 400:
            raise ProbeFailure("")
        counts.append(int(psql(ctx, _COUNT_SQL)))

    if "max_queries" in params and any(c > params["max_queries"] for c in counts):
        raise ProbeFailure("")
    if len(counts) > 1 and counts[-1] - counts[0] > int(params.get("max_growth", 0)):
        raise ProbeFailure("")

    for ex in params.get("explain", []):
        out = psql(ctx, "EXPLAIN (FORMAT JSON) " + render(ex["sql"], rng, {"seed": ctx.seed}))
        try:
            plan = json.loads(out)
        except ValueError:
            raise ProbeFailure("") from None
        if _has_node(plan, ex.get("forbid", "Seq Scan"), ex.get("relation")):
            raise ProbeFailure("")
