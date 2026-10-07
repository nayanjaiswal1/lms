"""Smoke tests visible to everyone working on the API."""

from fastapi.testclient import TestClient

from backend.app.main import create_app


def test_health():
    client = TestClient(create_app())
    assert client.get("/api/health").json() == {"status": "ok"}


def test_unknown_route_is_a_404():
    assert TestClient(create_app()).get("/api/nope").status_code == 404
