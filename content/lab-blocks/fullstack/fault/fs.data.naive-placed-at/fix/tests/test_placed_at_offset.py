import re
from datetime import datetime, timezone

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

OFFSET = re.compile(r"(Z|[+-]\d{2}:\d{2})$")
NEWEST = datetime(2025, 3, 6, 2, 30, tzinfo=timezone.utc)


def parse(stamp):
    return datetime.fromisoformat(stamp.replace("Z", "+00:00"))


def test_every_listed_order_names_the_offset_of_its_placed_at():
    client = signed_in()
    for page in (1, 2, 3):
        for order in client.get("/api/orders", params={"page": page}).json()["items"]:
            assert OFFSET.search(order["placed_at"]), order["placed_at"]


def test_the_order_detail_names_the_offset_and_keeps_the_instant():
    placed_at = signed_in().get("/api/orders/23").json()["placed_at"]
    assert OFFSET.search(placed_at), placed_at
    assert parse(placed_at) == NEWEST

