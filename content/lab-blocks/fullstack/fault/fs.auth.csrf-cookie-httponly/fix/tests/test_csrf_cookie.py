"""The CSRF cookie is the one cookie the page script must be able to read."""

from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def login():
    return TestClient(create_app()).post("/api/auth/login", json={"email": "alice@shop.test", "password": PASSWORD})


def flags(response, name):
    line = next(h for h in response.headers.get_list("set-cookie") if h.startswith(f"{name}="))
    return line.lower()


def test_the_csrf_cookie_is_readable_by_scripts():
    assert "httponly" not in flags(login(), "csrf_token")


def test_the_session_cookie_stays_httponly():
    assert "httponly" in flags(login(), "session")
