from fastapi.testclient import TestClient

from backend.app.config import DEFAULT_ORIGINS, DEFAULT_PAGE_SIZE, load_settings
from backend.app.main import create_app


def test_health():
    assert TestClient(create_app()).get("/api/health").json() == {"status": "ok"}


def test_unknown_route_is_404():
    assert TestClient(create_app()).get("/api/does-not-exist").status_code == 404


def test_settings_defaults(monkeypatch):
    monkeypatch.delenv("SHOP_ALLOWED_ORIGINS", raising=False)
    settings = load_settings()
    assert settings.allowed_origins == [DEFAULT_ORIGINS]
    assert settings.default_page_size == DEFAULT_PAGE_SIZE


def test_settings_origins_come_from_the_environment(monkeypatch):
    monkeypatch.setenv("SHOP_ALLOWED_ORIGINS", "https://a.example.com, https://b.example.com,")
    assert load_settings().allowed_origins == ["https://a.example.com", "https://b.example.com"]


def test_validation_errors_use_the_error_envelope():
    response = TestClient(create_app()).post("/api/auth/login", json={"email": "alice@shop.test"})
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
