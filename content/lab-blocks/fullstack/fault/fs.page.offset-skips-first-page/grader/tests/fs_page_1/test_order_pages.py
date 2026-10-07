"""Pages start at 1: page 1 is the newest orders and the last page holds the remainder."""

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


def ids(client, page, **params):
    return [o["id"] for o in client.get("/api/orders", params={"page": page, **params}).json()["items"]]


def test_the_first_page_starts_at_the_newest_order():
    assert ids(signed_in(), 1) == list(range(23, 13, -1))


def test_a_middle_page_follows_the_first():
    assert ids(signed_in(), 2) == list(range(13, 3, -1))


def test_the_last_page_holds_the_remainder():
    assert ids(signed_in(), 3) == [3, 2, 1]


def test_pages_do_not_overlap_or_skip():
    client = signed_in()
    assert ids(client, 1) + ids(client, 2) + ids(client, 3) == list(range(23, 0, -1))


def test_a_custom_page_size_uses_the_same_rule():
    assert ids(signed_in(), 2, page_size=5) == list(range(18, 13, -1))


def test_a_customer_with_a_few_orders_sees_them_on_page_one():
    client = signed_in("bob@shop.test")
    body = client.get("/api/orders").json()
    assert body["total"] == 3
    assert len(body["items"]) == 3
