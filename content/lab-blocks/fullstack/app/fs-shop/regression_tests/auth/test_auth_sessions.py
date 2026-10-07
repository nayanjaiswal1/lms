from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def login(client, email="alice@shop.test", password=PASSWORD):
    return client.post("/api/auth/login", json={"email": email, "password": password})


def with_session(client, response):
    """Attach the login cookies explicitly (the test client then sends them to every path)."""
    session, csrf = response.cookies.get("session"), response.cookies.get("csrf_token")
    client.cookies.clear()
    client.headers.update({"Cookie": f"session={session}; csrf_token={csrf}", "X-CSRF-Token": csrf})
    return client


def test_login_returns_the_user_and_both_cookies():
    client = TestClient(create_app())
    response = login(client)
    assert response.status_code == 200
    assert response.json()["user"] == {"id": 1, "email": "alice@shop.test", "name": "Alice Nguyen"}
    assert response.cookies.get("session")
    assert response.cookies.get("csrf_token")
    assert "httponly" in response.headers["set-cookie"].lower()


def test_wrong_password_and_unknown_email_are_rejected_alike():
    client = TestClient(create_app())
    for response in (login(client, password="nope"), login(client, email="ghost@shop.test")):
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "invalid_credentials"


def test_me_needs_a_session():
    client = TestClient(create_app())
    assert client.get("/api/auth/me").status_code == 401
    with_session(client, login(client))
    assert client.get("/api/auth/me").json()["user"]["email"] == "alice@shop.test"


def test_logout_ends_the_session():
    client = TestClient(create_app())
    with_session(client, login(client))
    assert client.post("/api/auth/logout").status_code == 200
    assert client.get("/api/auth/me").status_code == 401


def test_logout_without_the_csrf_header_is_forbidden():
    client = TestClient(create_app())
    with_session(client, login(client))
    del client.headers["X-CSRF-Token"]
    assert client.post("/api/auth/logout").status_code == 403
    assert client.get("/api/auth/me").status_code == 200
