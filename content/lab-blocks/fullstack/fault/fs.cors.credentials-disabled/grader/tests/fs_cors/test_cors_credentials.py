"""Cross-origin calls from the console must be allowed to carry the session cookie."""

from fastapi.testclient import TestClient

from backend.app.config import Settings
from backend.app.main import create_app

CONSOLE = "https://console.shop.test"
EVIL = "https://evil.mindforge.test"


def client():
    return TestClient(create_app(Settings(allowed_origins=[CONSOLE])))


def test_a_credentialed_response_names_the_console_and_allows_credentials():
    response = client().get("/api/health", headers={"Origin": CONSOLE})
    assert response.headers.get("access-control-allow-origin") == CONSOLE
    assert response.headers.get("access-control-allow-credentials") == "true"


def test_the_preflight_of_a_write_is_accepted_with_credentials():
    response = client().options(
        "/api/profile",
        headers={
            "Origin": CONSOLE,
            "Access-Control-Request-Method": "PUT",
            "Access-Control-Request-Headers": "content-type,x-csrf-token",
        },
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == CONSOLE
    assert response.headers["access-control-allow-credentials"] == "true"
    assert "x-csrf-token" in response.headers["access-control-allow-headers"].lower()


def test_other_origins_are_still_refused():
    response = client().get("/api/health", headers={"Origin": EVIL})
    assert "access-control-allow-origin" not in response.headers
