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


def all_orders(client):
    return [o for page in (1, 2, 3) for o in client.get("/api/orders", params={"page": page}).json()["items"]]


def test_every_total_is_an_integer_number_of_cents():
    for order in all_orders(signed_in()):
        assert type(order["total_cents"]) is int, order


def test_the_total_matches_the_lines_of_the_order():
    client = signed_in()
    detail = client.get("/api/orders/23").json()
    assert detail["total_cents"] == sum(i["quantity"] * i["unit_cents"] for i in detail["items"]) == 47700
    for order in all_orders(client):
        lines = client.get(f"/api/orders/{order['id']}").json()["items"]
        assert order["total_cents"] == sum(i["quantity"] * i["unit_cents"] for i in lines)
