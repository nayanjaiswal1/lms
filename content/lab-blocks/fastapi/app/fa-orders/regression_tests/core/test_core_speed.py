from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import metrics
from app.testing import *  # noqa: F401,F403


def test_percentile_interpolates_inside_the_bucket_and_never_exceeds_the_max():
    hist = [0] * (len(metrics.BUCKETS_MS) + 1)
    assert metrics.percentile(hist, 0.95, 0.0) == 0.0
    hist[metrics.BUCKETS_MS.index(10)] = 100  # 100 requests in (5, 10] ms
    assert metrics.percentile(hist, 0.50, 9.0) == 7.5
    assert metrics.percentile(hist, 0.99, 9.0) == 9.0  # clamped to the observed max
    hist[-1] = 1  # one request above the last bucket
    assert metrics.percentile(hist, 1.0, 12000.0) == 12000.0


def test_percentiles_split_two_populations():
    stats = metrics.RouteStats()
    for _ in range(90):
        stats.add(200, 3.0, 1000)
    for _ in range(10):
        stats.add(500, 800.0, 1000)
    summary = stats.summary(1000)
    assert summary["count"] == 100 and summary["status"]["5xx"] == 10
    assert summary["p50"] <= 5 < 500 <= summary["p99"] <= 800 == summary["max"]


def _speed_app() -> FastAPI:
    app = FastAPI()

    @app.get("/items/{item_id}")
    async def item(item_id: int) -> dict[str, int]:
        return {"id": item_id}

    @app.get("/boom")
    async def boom() -> None:
        raise RuntimeError("boom")

    metrics.install(app)
    return app


def test_route_templates_bound_the_cardinality_and_unknown_paths_collapse():
    metrics.STATS.reset()
    with TestClient(_speed_app(), raise_server_exceptions=False) as client:
        for i in range(30):
            client.get(f"/items/{i}")
        client.get("/nope-1")
        client.get("/nope-2")
        client.get("/boom")
        data = client.get("/__speed/data").json()
    rows = {(r["method"], r["route"]): r for r in data["routes"]}
    assert set(rows) == {("GET", "/items/{item_id}"), ("GET", "other"), ("GET", "/boom")}
    assert rows[("GET", "/items/{item_id}")]["count"] == 30
    assert rows[("GET", "other")]["status"]["4xx"] == 2
    assert rows[("GET", "/boom")]["status"]["5xx"] == 1
    assert data["inflight"] == 0 and data["pool"] is None


def test_speed_endpoints_are_excluded_unauthenticated_hidden_and_resettable():
    metrics.STATS.reset()
    app = _speed_app()
    with TestClient(app) as client:
        client.get("/items/1")
        page = client.get("/__speed")
        assert page.status_code == 200 and "text/html" in page.headers["content-type"]
        assert "http://" not in page.text.replace("http://www.w3.org", "") and "https://" not in page.text
        data = client.get("/__speed/data").json()
        assert [r["route"] for r in data["routes"]] == ["/items/{item_id}"]
        assert not [p for p in client.get("/openapi.json").json()["paths"] if p.startswith("/__speed")]
        assert client.post("/__speed/reset").status_code == 200
        assert client.get("/__speed/data").json()["routes"] == []


def test_the_real_app_serves_the_dashboard(client):
    assert client.get("/__speed").status_code == 200
    client.get("/healthz")
    data = client.get("/__speed/data").json()
    assert any(r["route"] == "/healthz" for r in data["routes"])
    assert data["pool"]["size"] >= 1
    assert "/__speed" not in client.get("/openapi.json").text


def test_process_identity_is_stable_within_a_process_survives_reset_and_differs_per_instance():
    stats = metrics.Stats()
    other = metrics.Stats()
    assert stats.boot_id != other.boot_id and len(stats.boot_id) == 32
    boot, started = stats.boot_id, stats.started_at
    stats.reset()
    snap = stats.snapshot(None)
    assert snap["boot_id"] == boot and snap["started_at"] == round(started, 3)
    assert snap["started_at"] <= snap["now"]


def test_data_endpoint_reports_the_same_boot_id_across_polls_and_reset():
    app = _speed_app()
    with TestClient(app) as client:
        first = client.get("/__speed/data").json()
        client.post("/__speed/reset")
        second = client.get("/__speed/data").json()
    assert first["boot_id"] == second["boot_id"] == metrics.STATS.boot_id
    assert first["started_at"] == second["started_at"]


def test_dashboard_has_baseline_and_load_controls_with_relative_urls_only():
    with TestClient(_speed_app()) as client:
        page = client.get("/__speed").text
    for element in ("mark-base", "clear-base", "reload", "changes", "lg-start", "lg-stop", "lg-path", "lg-conc", "lg-dur", "lg-auth"):
        assert f'id="{element}"' in page
    assert "Bearer mf_tok_alice" in page and "sessionStorage" in page
