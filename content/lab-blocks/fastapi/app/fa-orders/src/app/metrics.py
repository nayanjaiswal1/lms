"""In-process API speed metrics: a pure-ASGI middleware plus the ``/__speed`` dashboard.

Per (method, route template): request count, status-class counts, a fixed-bucket latency histogram (p50/p95/p99/max),
and a 60 s ring of per-second counts and histograms (rps and p95 sparklines). Globally: in-flight gauge, event-loop lag
and SQLAlchemy pool stats. Memory is bounded: keys are matched route templates (unmatched paths collapse to ``other``)
capped at MAX_ROUTES, the rings are fixed size, and nothing is persisted. Everything runs on the event loop thread, so
no locks. ``/__speed*`` is excluded from the stats, needs no auth and is hidden from OpenAPI.
"""

import asyncio
import time
import uuid
from bisect import bisect_left
from collections import deque

from fastapi import APIRouter, FastAPI, Request
from fastapi.responses import HTMLResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

PREFIX = "/__speed"
BUCKETS_MS = (1, 2, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000)  # one more bucket: above 10 s
METHODS = frozenset({"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"})
OTHER = "other"
MAX_ROUTES = 256
WINDOW = 60
RPS_SPAN = 10
LAG_INTERVAL = 0.1
LAG_SAMPLES = 300


def percentile(hist: list[int], q: float, max_ms: float) -> float:
    """``q`` in (0, 1] from bucket counts, interpolated inside the bucket and never above the observed max."""
    total = sum(hist)
    if total == 0:
        return 0.0
    rank = q * total
    seen = 0
    for i, n in enumerate(hist):
        if n and seen + n >= rank:
            lo = BUCKETS_MS[i - 1] if i > 0 else 0.0
            hi = BUCKETS_MS[i] if i < len(BUCKETS_MS) else max_ms
            return round(min(lo + (hi - lo) * (rank - seen) / n, max_ms), 2)
        seen += n
    return round(max_ms, 2)


def _empty_hist() -> list[int]:
    return [0] * (len(BUCKETS_MS) + 1)


class Window:
    """Last WINDOW seconds: per-second request count and latency histogram."""

    def __init__(self) -> None:
        self.slots = [[-1, 0, _empty_hist()] for _ in range(WINDOW)]

    def add(self, sec: int, bucket: int) -> None:
        slot = self.slots[sec % WINDOW]
        if slot[0] != sec:
            slot[0], slot[1], slot[2] = sec, 0, _empty_hist()
        slot[1] += 1
        slot[2][bucket] += 1

    def _live(self, now: int):
        for sec in range(now - WINDOW + 1, now + 1):
            slot = self.slots[sec % WINDOW]
            yield slot if slot[0] == sec else None

    def counts(self, now: int) -> list[int]:
        return [s[1] if s else 0 for s in self._live(now)]

    def p95(self, now: int, max_ms: float) -> list[float]:
        return [percentile(s[2], 0.95, max_ms) if s else 0.0 for s in self._live(now)]

    def rps(self, now: int) -> float:
        return round(sum(self.counts(now)[-RPS_SPAN:]) / RPS_SPAN, 2)


class RouteStats:
    def __init__(self) -> None:
        self.count = 0
        self.classes = {"2xx": 0, "3xx": 0, "4xx": 0, "5xx": 0}
        self.hist = _empty_hist()
        self.max_ms = 0.0
        self.total_ms = 0.0
        self.window = Window()

    def add(self, status: int, ms: float, sec: int) -> None:
        bucket = bisect_left(BUCKETS_MS, ms)
        self.count += 1
        self.total_ms += ms
        self.max_ms = max(self.max_ms, ms)
        self.hist[bucket] += 1
        self.window.add(sec, bucket)
        cls = f"{status // 100}xx"
        if cls in self.classes:
            self.classes[cls] += 1

    def summary(self, now: int) -> dict:
        return {
            "count": self.count,
            "rps": self.window.rps(now),
            "p50": percentile(self.hist, 0.50, self.max_ms),
            "p95": percentile(self.hist, 0.95, self.max_ms),
            "p99": percentile(self.hist, 0.99, self.max_ms),
            "max": round(self.max_ms, 2),
            "mean": round(self.total_ms / self.count, 2) if self.count else 0.0,
            "status": dict(self.classes),
        }


class Stats:
    def __init__(self) -> None:
        self.lag: deque[float] = deque(maxlen=LAG_SAMPLES)
        # Process identity: survives reset(), changes when the app process restarts (the dashboard uses it to detect a code reload).
        self.boot_id = uuid.uuid4().hex
        self.started_at = time.time()
        self.reset()

    def reset(self) -> None:
        self.started = time.time()
        self.routes: dict[tuple[str, str], RouteStats] = {}
        self.total = RouteStats()
        self.inflight = 0
        self.lag.clear()

    def record(self, method: str, template: str, status: int, ms: float) -> None:
        key = (method if method in METHODS else OTHER, template)
        if key not in self.routes and len(self.routes) >= MAX_ROUTES:
            key = (OTHER, OTHER)
        sec = int(time.time())
        self.routes.setdefault(key, RouteStats()).add(status, ms, sec)
        self.total.add(status, ms, sec)

    def snapshot(self, app: FastAPI | None) -> dict:
        now = int(time.time())
        rows = [{"method": m, "route": t, **r.summary(now)} for (m, t), r in self.routes.items()]
        rows.sort(key=lambda row: row["count"], reverse=True)
        lag = list(self.lag)
        return {
            "boot_id": self.boot_id,
            "started_at": round(self.started_at, 3),
            "now": round(time.time(), 3),
            "uptime_s": round(time.time() - self.started, 1),
            "inflight": self.inflight,
            "total": self.total.summary(now),
            "rps_series": self.total.window.counts(now),
            "p95_series": self.total.window.p95(now, self.total.max_ms),
            "event_loop_lag_ms": {
                "now": round(lag[-1], 2) if lag else 0.0,
                "max": round(max(lag), 2) if lag else 0.0,
                "window_s": round(LAG_SAMPLES * LAG_INTERVAL),
            },
            "pool": pool_stats(app),
            "routes": rows,
        }


STATS = Stats()


def pool_stats(app: FastAPI | None) -> dict | None:
    engine = getattr(getattr(app, "state", None), "engine", None)
    pool = getattr(getattr(engine, "sync_engine", None), "pool", None)
    if pool is None or not hasattr(pool, "checkedout"):
        return None
    settings = getattr(app.state, "settings", None)
    return {
        "size": pool.size(),
        "checked_out": pool.checkedout(),
        "overflow": max(0, pool.overflow()),
        "max_overflow": getattr(settings, "db_max_overflow", None),
    }


async def monitor_loop_lag() -> None:
    """Sleep LAG_INTERVAL repeatedly; the overshoot is how long the event loop was blocked."""
    loop = asyncio.get_running_loop()
    while True:
        started = loop.time()
        await asyncio.sleep(LAG_INTERVAL)
        STATS.lag.append(max(0.0, (loop.time() - started - LAG_INTERVAL) * 1000))


class MetricsMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["path"].startswith(PREFIX):
            await self.app(scope, receive, send)
            return
        status = 500  # stays 500 when the app raises before sending a response
        started = time.perf_counter()

        async def send_wrapper(message: Message) -> None:
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
            await send(message)

        STATS.inflight += 1
        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            STATS.inflight -= 1
            route = scope.get("route")  # FastAPI's router stores the matched route in the shared scope
            template = getattr(route, "path_format", None) or OTHER
            STATS.record(scope["method"], template, status, (time.perf_counter() - started) * 1000)


router = APIRouter(prefix=PREFIX, include_in_schema=False)


@router.get("")
async def dashboard() -> HTMLResponse:
    return HTMLResponse(DASHBOARD_HTML, headers={"Cache-Control": "no-store"})


@router.get("/data")
async def data(request: Request) -> dict:
    return STATS.snapshot(request.app)


@router.post("/reset")
async def reset() -> dict[str, str]:
    STATS.reset()
    return {"status": "reset"}


def install(app: FastAPI) -> None:
    """Add the middleware and the ``/__speed`` endpoints to ``app``."""
    app.add_middleware(MetricsMiddleware)
    app.include_router(router)


DASHBOARD_HTML = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>API speed</title>
<style>
:root { color-scheme: light dark; --bg:#fff; --fg:#1b1f24; --muted:#59636e; --line:#d1d9e0; --card:#f6f8fa; --accent:#0969da; --bad:#cf222e; --warn:#9a6700; --good:#1a7f37; }
@media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#e6edf3; --muted:#9198a1; --line:#30363d; --card:#161b22; --accent:#58a6ff; --bad:#ff7b72; --warn:#d29922; --good:#3fb950; } }
* { box-sizing: border-box; }
body { margin:0; padding:16px; background:var(--bg); color:var(--fg); font:14px/1.45 system-ui, sans-serif; }
header { display:flex; flex-wrap:wrap; align-items:center; gap:12px; margin-bottom:12px; }
h1 { font-size:18px; margin:0 auto 0 0; }
button { font:inherit; color:var(--fg); background:var(--card); border:1px solid var(--line); border-radius:6px; padding:5px 12px; cursor:pointer; }
button:focus-visible { outline:2px solid var(--accent); outline-offset:2px; }
#status { color:var(--muted); }
.cards { display:grid; grid-template-columns:repeat(auto-fit, minmax(190px, 1fr)); gap:10px; margin-bottom:14px; }
.card { background:var(--card); border:1px solid var(--line); border-radius:8px; padding:10px; }
.card h2 { font-size:12px; font-weight:600; margin:0 0 4px; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; }
.big { font-size:22px; font-weight:600; font-variant-numeric:tabular-nums; }
.sub { color:var(--muted); font-size:12px; }
svg.spark { width:100%; height:36px; display:block; }
svg.spark polyline { fill:none; stroke:var(--accent); stroke-width:1.5; vector-effect:non-scaling-stroke; }
.table-wrap { overflow-x:auto; }
table { border-collapse:collapse; width:100%; font-variant-numeric:tabular-nums; }
caption { text-align:left; font-weight:600; padding:4px 0 8px; }
th, td { padding:5px 9px; border-bottom:1px solid var(--line); text-align:right; white-space:nowrap; }
th:first-child, td:first-child { text-align:left; }
th { color:var(--muted); font-weight:600; }
.bad { color:var(--bad); font-weight:600; }
.warn { color:var(--warn); font-weight:600; }
.good { color:var(--good); font-weight:600; }
.delta { font-size:11px; font-weight:400; }
.delta.good, .delta.bad { font-weight:600; }
.banner { display:flex; gap:10px; align-items:center; border:1px solid var(--warn); border-radius:8px; padding:8px 12px; margin-bottom:12px; background:var(--card); }
.banner[hidden] { display:none; }
.summary { font-size:15px; font-weight:600; margin:0 0 12px; }
.panel { border:1px solid var(--line); border-radius:8px; background:var(--card); padding:10px; margin-top:14px; }
.panel h2 { font-size:14px; margin:0 0 8px; }
.panel .row { display:flex; flex-wrap:wrap; gap:10px; align-items:end; }
label { display:flex; flex-direction:column; gap:2px; font-size:12px; color:var(--muted); }
input, select { font:inherit; color:var(--fg); background:var(--bg); border:1px solid var(--line); border-radius:6px; padding:4px 8px; }
input:focus-visible, select:focus-visible { outline:2px solid var(--accent); outline-offset:2px; }
button:disabled { opacity:.5; cursor:default; }
</style>
</head>
<body>
<header>
  <h1>API speed</h1>
  <span id="status" role="status" aria-live="polite">loading...</span>
  <button id="toggle" type="button" aria-pressed="false">Pause</button>
  <button id="reset" type="button">Reset</button>
  <button id="mark-base" type="button">Mark baseline</button>
  <button id="clear-base" type="button" disabled>Clear baseline</button>
</header>
<div id="reload" class="banner" role="status" hidden><span id="reload-msg"></span><button id="reload-dismiss" type="button">Dismiss</button></div>
<p class="sub" id="restarted"></p>
<p class="summary" id="changes" aria-live="polite"></p>
<p class="sub" id="base-note"></p>
<section class="cards" aria-label="Summary">
  <div class="card"><h2>Requests per second</h2><div class="big" id="rps">0</div><svg id="rps-spark" class="spark" role="img" aria-label="Requests per second, last 60 seconds" viewBox="0 0 60 30" preserveAspectRatio="none"><polyline points=""/></svg><div class="sub">last 60 s</div></div>
  <div class="card"><h2>p95 latency</h2><div class="big" id="p95">0 ms</div><svg id="p95-spark" class="spark" role="img" aria-label="p95 latency, last 60 seconds" viewBox="0 0 60 30" preserveAspectRatio="none"><polyline points=""/></svg><div class="sub" id="p95-sub"></div></div>
  <div class="card"><h2>Event loop lag</h2><div class="big" id="lag">0 ms</div><div class="sub" id="lag-sub"></div><div class="sub">Rises when a handler blocks the event loop.</div></div>
  <div class="card"><h2>DB pool</h2><div class="big" id="pool">n/a</div><div class="sub" id="pool-sub"></div><div class="sub" id="inflight"></div></div>
</section>
<div class="table-wrap">
<table>
  <caption>Per route (latency in ms, err = 4xx+5xx share, rps over the last 10 s; "was" is the baseline)</caption>
  <thead><tr><th scope="col">Route</th><th scope="col">Count</th><th scope="col">p50</th><th scope="col">p95</th><th scope="col">p99</th><th scope="col">err %</th><th scope="col">rps</th><th scope="col">max</th><th scope="col">5xx</th></tr></thead>
  <tbody id="rows"><tr><td colspan="9">No requests yet. Use Send load below, or run <code>python3 scripts/bench.py /healthz</code> in the terminal.</td></tr></tbody>
</table>
</div>
<section class="panel" aria-labelledby="lg-h">
  <h2 id="lg-h">Send load (GET, same origin)</h2>
  <div class="row">
    <label>Route seen so far<select id="lg-route"><option value="">Pick a route seen so far</option></select></label>
    <label>Path<input id="lg-path" type="text" value="/healthz" size="28" spellcheck="false"></label>
    <label>Concurrency (1-20)<input id="lg-conc" type="number" min="1" max="20" value="5" style="width:5em"></label>
    <label>Duration s (5-30)<input id="lg-dur" type="number" min="5" max="30" value="10" style="width:5em"></label>
    <label>Authorization header<input id="lg-auth" type="text" value="Bearer mf_tok_alice" size="24" spellcheck="false"></label>
    <button id="lg-start" type="button">Start</button>
    <button id="lg-stop" type="button" disabled>Stop</button>
  </div>
  <p class="sub" id="lg-status" role="status">Idle. Requests go through the same metrics middleware as real traffic.</p>
</section>
<script>
(function () {
  var base = location.pathname.replace(/\\/+$/, "");
  var prefix = base.slice(0, base.length - "/__speed".length);
  var KEY_BASE = "mf_speed_baseline", KEY_LAST = "mf_speed_last";
  var paused = false, timer = null, lastData = null, lastGood = null, bootId = null, baseline = null, routeKey = "", pathEdited = false;
  var $ = function (id) { return document.getElementById(id); };
  function load(k) { try { var v = sessionStorage.getItem(k); return v ? JSON.parse(v) : null; } catch (e) { return null; } }
  function save(k, v) { try { if (v == null) sessionStorage.removeItem(k); else sessionStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* page works without storage */ } }
  function ms(v) { return v >= 1000 ? (v / 1000).toFixed(v >= 10000 ? 0 : 1) + " s" : (v >= 100 ? v.toFixed(0) : v.toFixed(1)) + " ms"; }
  function pct(v) { return v.toFixed(1) + "%"; }
  function ago(s) {
    s = Math.max(0, Math.round(s));
    return s < 60 ? s + " s ago" : s < 3600 ? Math.floor(s / 60) + " min ago" : Math.floor(s / 3600) + " h " + Math.floor(s % 3600 / 60) + " min ago";
  }
  function spark(id, series) {
    var max = Math.max.apply(null, series.concat([1]));
    var pts = series.map(function (v, i) { return i + "," + (30 - (v / max) * 28 - 1).toFixed(1); });
    $(id).firstElementChild.setAttribute("points", pts.join(" "));
  }
  function errPct(r) { return r.count ? (r.status["4xx"] + r.status["5xx"]) * 100 / r.count : 0; }
  function metricsOf(r) { return { p50: r.p50, p95: r.p95, p99: r.p99, err: errPct(r), rps: r.rps }; }
  function snapshot(d) {
    var routes = {};
    d.routes.forEach(function (r) { routes[r.method + " " + r.route] = metricsOf(r); });
    return { at: Date.now(), boot: d.boot_id, routes: routes };
  }
  var METRICS = [
    { k: "p50", fmt: ms, lower: true }, { k: "p95", fmt: ms, lower: true }, { k: "p99", fmt: ms, lower: true },
    { k: "err", fmt: pct, lower: true }, { k: "rps", fmt: function (v) { return v.toFixed(1); }, lower: false }
  ];
  function delta(cur, old, m) {
    var change = old ? (cur - old) * 100 / old : (cur ? 100 : 0);
    if (Math.abs(change) < 5) return { text: "≈ no change", cls: "" };
    var better = m.lower ? change < 0 : change > 0;
    return { text: (change < 0 ? "▼ " : "▲ ") + (change > 0 ? "+" : "") + change.toFixed(0) + "% " + (better ? "better" : "worse"), cls: better ? "good" : "bad" };
  }
  function cell(tr, text, cls) {
    var td = document.createElement("td");
    td.textContent = text;
    if (cls) td.className = cls;
    tr.appendChild(td);
    return td;
  }
  function metricCell(tr, m, cur, old, plainCls) {
    var td = cell(tr, m.fmt(cur), plainCls);
    if (!old) return;
    var dl = delta(cur, old[m.k], m);
    var sub = document.createElement("div");
    sub.className = "delta " + dl.cls;
    sub.textContent = "was " + m.fmt(old[m.k]) + " " + dl.text;
    td.appendChild(sub);
  }
  function summaryLine(d) {
    if (!baseline) return "No baseline yet. Click Mark baseline, or edit code and the app will reload with the previous run as baseline.";
    var best = null;
    d.routes.forEach(function (r) {
      var old = baseline.routes[r.method + " " + r.route];
      if (!old || !r.count || !old.p95) return;
      var change = (r.p95 - old.p95) * 100 / old.p95;
      if (Math.abs(change) >= 5 && (!best || Math.abs(r.p95 - old.p95) > Math.abs(best.cur - best.old))) best = { name: r.route, cur: r.p95, old: old.p95, change: change };
    });
    if (!best) return "No significant p95 change since baseline.";
    return "p95 of " + best.name + ": " + ms(best.old) + " -> " + ms(best.cur) + " since baseline (" + (best.change > 0 ? "+" : "") + best.change.toFixed(0) + "%, " + (best.change < 0 ? "faster" : "slower") + ")";
  }
  function updateRoutes(d) {
    var seen = d.routes.map(function (r) { return r.route; }).filter(function (v, i, a) { return a.indexOf(v) === i; });
    var key = seen.join("|");
    if (key !== routeKey) {
      routeKey = key;
      var sel = $("lg-route"), keep = sel.value;
      sel.textContent = "";
      var first = document.createElement("option");
      first.value = ""; first.textContent = "Pick a route seen so far";
      sel.appendChild(first);
      seen.forEach(function (route) { var o = document.createElement("option"); o.value = o.textContent = route; sel.appendChild(o); });
      sel.value = seen.indexOf(keep) >= 0 ? keep : "";
    }
    if (!pathEdited) {
      var slow = d.routes.filter(function (r) { return r.route !== "other" && r.route.charAt(0) === "/"; })
        .sort(function (a, b) { return b.p95 - a.p95; })[0];
      if (slow) $("lg-path").value = slow.route;
    }
  }
  function render(d) {
    $("rps").textContent = d.total.rps.toFixed(1);
    $("p95").textContent = ms(d.total.p95);
    $("p95-sub").textContent = "p50 " + ms(d.total.p50) + " / p99 " + ms(d.total.p99) + " / max " + ms(d.total.max);
    spark("rps-spark", d.rps_series);
    spark("p95-spark", d.p95_series);
    var lag = d.event_loop_lag_ms;
    $("lag").textContent = ms(lag.now);
    $("lag").className = "big " + (lag.max > 250 ? "bad" : lag.max > 50 ? "warn" : "");
    $("lag-sub").textContent = "max " + ms(lag.max) + " in the last " + lag.window_s + " s";
    var p = d.pool;
    $("pool").textContent = p ? p.checked_out + " / " + p.size : "n/a";
    $("pool").className = "big " + (p && p.checked_out >= p.size ? "warn" : "");
    $("pool-sub").textContent = p ? "checked out / pool size, overflow " + p.overflow + (p.max_overflow == null ? "" : " of " + p.max_overflow) : "no database engine";
    $("inflight").textContent = d.inflight + " in flight, stats window " + d.uptime_s.toFixed(0) + " s";
    $("restarted").textContent = "App restarted " + ago(d.now - d.started_at);
    $("changes").textContent = summaryLine(d);
    $("clear-base").disabled = !baseline;
    $("base-note").textContent = baseline ? "Baseline set " + ago((Date.now() - baseline.at) / 1000) : "";
    updateRoutes(d);
    var body = $("rows");
    body.textContent = "";
    if (!d.routes.length) {
      var empty = document.createElement("tr");
      var td = document.createElement("td");
      td.colSpan = 9;
      td.textContent = "No requests yet. Use Send load below.";
      empty.appendChild(td);
      body.appendChild(empty);
    }
    d.routes.forEach(function (r) {
      var tr = document.createElement("tr");
      var old = baseline && baseline.routes[r.method + " " + r.route];
      var cur = metricsOf(r);
      cell(tr, r.method + " " + r.route);
      cell(tr, r.count);
      METRICS.forEach(function (m) {
        metricCell(tr, m, cur[m.k], old, m.k === "p95" ? (r.p95 > 500 ? "bad" : r.p95 > 100 ? "warn" : "") : m.k === "err" && cur.err ? "warn" : "");
      });
      cell(tr, ms(r.max));
      cell(tr, r.status["5xx"], r.status["5xx"] ? "bad" : "");
      body.appendChild(tr);
    });
  }
  function onData(d) {
    if (bootId == null) { var stored = load(KEY_LAST); bootId = stored ? stored.boot : d.boot_id; lastGood = stored; }
    if (d.boot_id !== bootId) {
      var promoted = !!(lastGood && Object.keys(lastGood.routes).length);
      if (promoted) {
        baseline = lastGood;
        save(KEY_BASE, baseline);
      }
      $("reload-msg").textContent = "Code reloaded - stats were reset (" + new Date().toLocaleTimeString() + ")." + (promoted ? " The previous run is now the baseline." : " There was no previous run to use as a baseline.");
      $("reload").hidden = false;
      bootId = d.boot_id;
      lastGood = null;
    }
    lastData = d;
    if (d.routes.length) { lastGood = snapshot(d); save(KEY_LAST, lastGood); }
    render(d);
  }
  function tick() {
    fetch(new URL(base + "/data", location.href), { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw new Error("HTTP " + r.status); return r.json(); })
      .then(function (d) { onData(d); $("status").textContent = "updated " + new Date().toLocaleTimeString(); })
      .catch(function (e) { $("status").textContent = "cannot load stats: " + e.message; });
  }
  function schedule() { clearInterval(timer); if (!paused) timer = setInterval(tick, 2000); }
  $("toggle").addEventListener("click", function () {
    paused = !paused;
    this.textContent = paused ? "Resume" : "Pause";
    this.setAttribute("aria-pressed", String(paused));
    schedule();
  });
  $("reset").addEventListener("click", function () {
    fetch(new URL(base + "/reset", location.href), { method: "POST" }).then(tick);
  });
  $("mark-base").addEventListener("click", function () {
    if (!lastData) return;
    baseline = snapshot(lastData);
    save(KEY_BASE, baseline);
    render(lastData);
  });
  $("clear-base").addEventListener("click", function () {
    baseline = null;
    save(KEY_BASE, null);
    if (lastData) render(lastData);
  });
  $("reload-dismiss").addEventListener("click", function () { $("reload").hidden = true; });

  var run = null;
  function lgStatus(text) { $("lg-status").textContent = text; }
  function lgCounters() {
    if (!run) return;
    lgStatus((run.active ? "Running: " : "Stopped: ") + run.sent + " sent, " + run.ok + " ok, " + run.fail + " failed, " + run.inflight + " in flight" + (run.active ? ", " + Math.max(0, Math.ceil((run.end - Date.now()) / 1000)) + " s left" : "") + (run.err ? " (" + run.err + ")" : ""));
  }
  function lgStop() {
    if (!run || !run.active) return;
    run.active = false;
    run.ctrl.abort();
    clearInterval(run.ui);
    $("lg-start").disabled = false;
    $("lg-stop").disabled = true;
    lgCounters();
  }
  function lgStart() {
    var path = $("lg-path").value.trim();
    if (path.charAt(0) !== "/" || path.slice(0, 2) === "//") { lgStatus("Path must start with a single / (same origin only)."); return; }
    var n = Math.min(20, Math.max(1, parseInt($("lg-conc").value, 10) || 1));
    var secs = Math.min(30, Math.max(5, parseInt($("lg-dur").value, 10) || 10));
    $("lg-conc").value = n; $("lg-dur").value = secs;
    var url = new URL(prefix + path, location.href);
    var headers = {}, auth = $("lg-auth").value.trim();
    if (auth) headers.Authorization = auth;
    run = { active: true, sent: 0, ok: 0, fail: 0, inflight: 0, err: "", end: Date.now() + secs * 1000, ctrl: new AbortController() };
    var r = run;
    function worker() {
      if (!r.active || Date.now() >= r.end) return Promise.resolve();
      r.inflight++; r.sent++;
      return fetch(url, { headers: headers, cache: "no-store", signal: r.ctrl.signal })
        .then(function (res) { if (res.ok) r.ok++; else { r.fail++; r.err = "HTTP " + res.status; } return res.arrayBuffer(); })
        .catch(function (e) { if (!r.ctrl.signal.aborted) { r.fail++; r.err = e.message; } })
        .then(function () { r.inflight--; return worker(); });
    }
    var all = [];
    for (var i = 0; i < n; i++) all.push(worker());
    r.ui = setInterval(function () { if (Date.now() >= r.end) lgStop(); else lgCounters(); }, 250);
    $("lg-start").disabled = true;
    $("lg-stop").disabled = false;
    lgCounters();
    Promise.all(all).then(function () { if (r === run) lgStop(); });
  }
  $("lg-start").addEventListener("click", lgStart);
  $("lg-stop").addEventListener("click", lgStop);
  $("lg-route").addEventListener("change", function () { if (this.value) { $("lg-path").value = this.value; pathEdited = true; } });
  $("lg-path").addEventListener("input", function () { pathEdited = true; });
  window.addEventListener("pagehide", lgStop);

  baseline = load(KEY_BASE);
  tick();
  schedule();
})();
</script>
</body>
</html>
"""
