"""The session cookie must reach every API path, not only the auth routes."""

from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def signed_in():
    client = TestClient(create_app())
    response = client.post("/api/auth/login", json={"email": "alice@shop.test", "password": PASSWORD})
    assert response.status_code == 200
    return client, response


def attributes(response, name):
    line = next(h for h in response.headers.get_list("set-cookie") if h.startswith(f"{name}="))
    return {part.split("=")[0].strip().lower(): part.partition("=")[2].strip() for part in line.split(";")[1:]}


def test_the_session_cookie_is_sent_to_the_orders_api():
    client, _ = signed_in()
    assert client.get("/api/orders").status_code == 200


def test_the_session_cookie_is_sent_to_the_other_endpoints_too():
    client, _ = signed_in()
    assert client.get("/api/auth/me").status_code == 200
    assert client.get("/api/profile").status_code == 200


def test_the_session_cookie_covers_the_api_and_stays_httponly():
    _, response = signed_in()
    attrs = attributes(response, "session")
    assert attrs["path"] in ("/", "/api")
    assert "httponly" in attrs
