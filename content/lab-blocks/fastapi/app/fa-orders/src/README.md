# Orders

The orders service of a small online shop: catalog, orders, customer wallet credit, payments through an
external provider, feature flags and staff reports. FastAPI, async SQLAlchemy 2, Alembic, PostgreSQL.

## Working on it

```bash
. scripts/dev-env.sh            # DATABASE_URL and service URLs for this sandbox
python3 -m alembic upgrade head # schema
python3 -m pytest               # tests live in tests/
tail -f /var/log/mindforge-lab/app.log
```

The lab already runs the API for you on :8000 (interactive docs at `/docs`). Seeded demo accounts use the
password `shop-pass-1` and the API token `mf_tok_<name>` (`alice`, `bob`, `carol`, `dan`, `erin`, `frank`, and
`staff` for the staff account). Send it as `Authorization: Bearer mf_tok_alice`.

## Speed and metrics

Open `/__speed` in the preview pane (or `http://localhost:8000/__speed`): per route count, requests per second, p50/p95/p99/max
latency and 4xx/5xx counts, rps and p95 sparklines, event-loop lag (rises when a handler blocks the loop) and DB pool usage
(checked out / size, overflow). It refreshes every 2 s; Reset clears it. The same numbers are JSON at `/__speed/data`.
Stats are per process, grouped by route template (`/api/v1/orders/{order_id}`), and need no token.

Generate load from the terminal and watch the dashboard:

```bash
python3 scripts/bench.py /api/v1/orders -n 200 -c 20 -H 'Authorization: Bearer mf_tok_alice'
```

It prints errors, requests per second and min/p50/p95/p99/max latency. Compare a slow route against a fast one such as `/healthz`.

The page also has a **Send load** panel (route, concurrency 1-20, duration 5-30 s, Authorization header) that sends GET requests from your browser to this same app; they are counted like any other traffic, so you can reproduce a load, fix the code, and re-run without leaving the page.

Seeing the impact of a change:

- `/__speed/data` also returns `boot_id` (random per process) and `started_at`; the page shows "App restarted ... ago".
- When the app restarts after you edit code, the page shows "Code reloaded - stats were reset" and keeps the previous run (p50/p95/p99, error %, rps per route) as the **baseline**. **Mark baseline** snapshots the current numbers; **Clear baseline** drops it. The baseline lives in `sessionStorage` (the page works without it).
- With a baseline set, each table cell shows the current value plus "was X" and a delta such as `p95 480 ms -> 60 ms`, `-88% better` or `+40% worse` (arrows and words, not only colour), and the line at the top summarises the biggest p95 change.
