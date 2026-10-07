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


def stock(client, sku):
    return client.get("/api/products", params={"q": sku}).json()["items"][0]["stock"]


def order(product_id, quantity):
    return {"items": [{"product_id": product_id, "quantity": quantity}]}


def test_placing_an_order_creates_it_and_takes_the_stock():
    client = signed_in()
    created = client.post("/api/orders", json=order(2, 2))
    assert created.status_code == 201
    body = created.json()
    assert (body["id"], body["status"], body["item_count"]) == (27, "pending", 2)
    assert created.headers["location"] == "/api/orders/27"
    assert stock(client, "MS-210") == 38
    assert client.get("/api/orders").json()["total"] == 24


def test_stock_is_not_oversold():
    client = signed_in()
    assert client.post("/api/orders", json=order(6, 4)).status_code == 409
    assert stock(client, "MN-270") == 3


def test_unknown_products_and_bad_quantities_are_rejected():
    client = signed_in()
    assert client.post("/api/orders", json=order(999, 1)).status_code == 404
    assert client.post("/api/orders", json=order(2, 0)).status_code == 422
    assert client.post("/api/orders", json={"items": []}).status_code == 422
    assert client.post("/api/orders", json=order(4, 21)).status_code == 422


def test_an_order_needs_a_session_and_a_csrf_token():
    assert TestClient(create_app()).post("/api/orders", json=order(2, 1)).status_code == 401
    client = signed_in()
    del client.headers["X-CSRF-Token"]
    assert client.post("/api/orders", json=order(2, 1)).status_code == 403
    client.headers["X-CSRF-Token"] = "forged"
    assert client.post("/api/orders", json=order(2, 1)).status_code == 403


def test_the_same_product_twice_is_one_line():
    client = signed_in()
    body = {"items": [{"product_id": 4, "quantity": 1}, {"product_id": 4, "quantity": 2}]}
    assert client.post("/api/orders", json=body).json()["item_count"] == 3
