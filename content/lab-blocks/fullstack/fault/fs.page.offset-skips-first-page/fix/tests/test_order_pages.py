from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def signed_in(email="alice@shop.test"):
    client = TestClient(create_app())
    login = client.post("/api/auth/login", json={"email": email, "password": PASSWORD})
    session, csrf = login.cookies.get("session"), login.cookies.get("csrf_token")
    client.cookies.clear()
    client.headers.update({"Cookie": f"session={session}; csrf_token={csrf}", "X-CSRF-Token": csrf})
    return client


def ids(client, page):
    return [o["id"] for o in client.get("/api/orders", params={"page": page}).json()["items"]]


def test_the_first_page_starts_at_the_newest_order():
    assert ids(signed_in(), 1) == list(range(23, 13, -1))
