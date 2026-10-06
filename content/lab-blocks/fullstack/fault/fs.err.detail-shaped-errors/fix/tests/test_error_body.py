"""Every API error carries {"error": {"code", "message"}}, the shape the console reads."""

from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def signed_in():
    client = TestClient(create_app())
    login = client.post("/api/auth/login", json={"email": "alice@shop.test", "password": PASSWORD})
    session, csrf = login.cookies.get("session"), login.cookies.get("csrf_token")
    client.cookies.clear()
    client.headers.update({"Cookie": f"session={session}; csrf_token={csrf}", "X-CSRF-Token": csrf})
    return client


def test_a_missing_order_has_the_error_envelope():
    response = signed_in().get("/api/orders/9999")
    assert response.status_code == 404
    body = response.json()
    assert "detail" not in body
    assert body["error"]["code"] == "order_not_found"
    assert body["error"]["message"] == "No such order."


def test_an_unknown_product_has_the_error_envelope():
    response = signed_in().post("/api/orders", json={"items": [{"product_id": 999, "quantity": 1}]})
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "product_not_found"


def test_a_rejected_csrf_check_has_the_error_envelope():
    client = signed_in()
    del client.headers["X-CSRF-Token"]
    response = client.post("/api/auth/logout")
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "csrf_failed"
