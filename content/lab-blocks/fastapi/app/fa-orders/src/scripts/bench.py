#!/usr/bin/env python3
"""Tiny load generator: bench <path> [-n 200] [-c 20] [-H 'Authorization: Bearer mf_tok_alice'].

Sends N GET requests with C in flight against the running app (BENCH_BASE_URL, default http://127.0.0.1:8000) and prints
errors, requests per second and min/p50/p95/p99/max latency. Per-route numbers, event-loop lag and DB pool usage are
live at /__speed in the preview pane.
"""

import argparse
import asyncio
import math
import os
import sys
import time

import httpx


def pct(sorted_ms: list[float], q: float) -> float:
    return sorted_ms[min(len(sorted_ms) - 1, math.ceil(q * len(sorted_ms)) - 1)]


async def run(url: str, total: int, concurrency: int, headers: dict[str, str]) -> tuple[list[float], int, float]:
    latencies: list[float] = []
    errors = 0
    gate = asyncio.Semaphore(concurrency)

    async with httpx.AsyncClient(headers=headers, timeout=30, limits=httpx.Limits(max_connections=concurrency)) as client:

        async def one() -> None:
            nonlocal errors
            async with gate:
                started = time.perf_counter()
                try:
                    errors += (await client.get(url)).status_code >= 400
                except httpx.HTTPError:
                    errors += 1
                latencies.append((time.perf_counter() - started) * 1000)

        started = time.perf_counter()
        await asyncio.gather(*(one() for _ in range(total)))
        return latencies, errors, time.perf_counter() - started


def main() -> int:
    parser = argparse.ArgumentParser(prog="bench", description=__doc__.splitlines()[0])
    parser.add_argument("path", help="path such as /api/v1/orders, or a full URL")
    parser.add_argument("-n", "--requests", type=int, default=200)
    parser.add_argument("-c", "--concurrency", type=int, default=20)
    parser.add_argument("-H", "--header", action="append", default=[], metavar="'Name: value'")
    parser.add_argument("--base", default=os.environ.get("BENCH_BASE_URL", "http://127.0.0.1:8000"))
    args = parser.parse_args()
    if args.requests < 1 or args.concurrency < 1:
        parser.error("-n and -c must be at least 1")
    headers = {}
    for header in args.header:
        name, sep, value = header.partition(":")
        if not sep:
            parser.error(f"bad header {header!r}, expected 'Name: value'")
        headers[name.strip()] = value.strip()
    url = args.path if args.path.startswith("http") else args.base.rstrip("/") + "/" + args.path.lstrip("/")

    latencies, errors, elapsed = asyncio.run(run(url, args.requests, args.concurrency, headers))
    ms = sorted(latencies)
    print(f"GET {url}  n={args.requests} c={args.concurrency}")
    print(f"requests {len(ms)}   errors {errors}   time {elapsed:.2f}s   rps {len(ms) / elapsed:.1f}")
    print(
        f"latency ms   min {ms[0]:.1f}   p50 {pct(ms, 0.50):.1f}   p95 {pct(ms, 0.95):.1f}"
        f"   p99 {pct(ms, 0.99):.1f}   max {ms[-1]:.1f}"
    )
    print("Per-route stats, event-loop lag and DB pool: open /__speed in the preview pane.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
