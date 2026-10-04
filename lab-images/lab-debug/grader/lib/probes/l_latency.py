"""Kind L — latency / lock behavior while something slow is running.

params:
  background: {method, path, body?, count?}   slow call(s) fired concurrently
              (count defaults 1) — or {sql, count?} to hold a lock via psql
  probe:      {method?, path, samples?, p95_ms_max}   sampled while the
              background work runs; p95 must stay under p95_ms_max
  start_delay_ms: wait before sampling (default 200)
Wide margins are the author's job: prefer counts to wall-clock where possible.
"""
from __future__ import annotations

import threading
import time
from typing import Any

from .common import Context, ProbeFailure, http_request, psql

KIND = "L"


def run(ctx: Context, name: str, params: dict[str, Any]) -> None:
    bg = params["background"]
    probe = params["probe"]
    stop = threading.Event()

    def background() -> None:
        try:
            if "sql" in bg:
                psql(ctx, bg["sql"], timeout=int(bg.get("timeout", 30)))
            else:
                http_request(ctx, bg.get("method", "GET"), bg["path"], bg.get("headers"), bg.get("body"),
                             timeout=float(bg.get("timeout", 30)))
        except ProbeFailure:
            pass

    threads = [threading.Thread(target=background, daemon=True) for _ in range(int(bg.get("count", 1)))]
    for t in threads:
        t.start()
    time.sleep(params.get("start_delay_ms", 200) / 1000)

    durations: list[float] = []
    try:
        for _ in range(int(probe.get("samples", 20))):
            resp = http_request(ctx, probe.get("method", "GET"), probe["path"], timeout=float(probe.get("timeout", 10)))
            if resp.status >= 500:
                raise ProbeFailure("")
            durations.append(resp.elapsed * 1000)
            time.sleep(0.05)
    finally:
        stop.set()
        for t in threads:
            t.join(timeout=30)

    durations.sort()
    p95 = durations[min(len(durations) - 1, int(len(durations) * 0.95))]
    if p95 > float(probe["p95_ms_max"]):
        raise ProbeFailure("")
