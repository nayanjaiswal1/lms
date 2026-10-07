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


def test_orders_need_a_session():
    assert TestClient(create_app()).get("/api/orders").status_code == 401


def test_list_reports_the_customers_own_orders():
    body = signed_in().get("/api/orders").json()
    assert body["total"] == 23
    assert body["pages"] == 3
    assert body["page"] == 1
    assert len(body["items"]) <= 10
    assert {"id", "status", "item_count"} <= set(body["items"][0])


def test_page_size_is_honoured_and_capped():
    client = signed_in()
    assert client.get("/api/orders", params={"page_size": 5}).json()["pages"] == 5
    assert len(client.get("/api/orders", params={"page_size": 500}).json()["items"]) <= 50


def test_a_customer_with_few_orders_has_one_page():
    body = signed_in("bob@shop.test").get("/api/orders").json()
    assert (body["total"], body["pages"]) == (3, 1)


def test_page_must_be_positive():
    assert signed_in().get("/api/orders", params={"page": 0}).status_code == 422


def test_order_detail_belongs_to_its_customer():
    alice = signed_in()
    detail = alice.get("/api/orders/23")
    assert detail.status_code == 200
    assert detail.json()["id"] == 23
    assert len(detail.json()["items"]) == 1
    assert alice.get("/api/orders/24").status_code == 404
