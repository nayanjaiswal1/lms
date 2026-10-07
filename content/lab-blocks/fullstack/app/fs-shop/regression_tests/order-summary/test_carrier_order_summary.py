from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def signed_in(email):
    client = TestClient(create_app())
    login = client.post("/api/auth/login", json={"email": email, "password": PASSWORD})
    client.cookies.clear()
    client.headers.update({"Cookie": f"session={login.cookies.get('session')}"})
    return client


def test_summary_counts_orders_per_status_and_spend():
    body = signed_in("bob@shop.test").get("/api/reports/order-summary").json()
    assert body["orders"] == 3
    assert sum(body["by_status"].values()) == 3
    assert body["spent_cents"] > 0


def test_summary_needs_a_session():
    assert TestClient(create_app()).get("/api/reports/order-summary").status_code == 401
