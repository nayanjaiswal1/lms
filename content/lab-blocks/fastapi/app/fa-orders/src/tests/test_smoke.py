"""Smoke tests visible to everyone working on the orders service."""

from app.testing import *  # noqa: F401,F403


def test_health_endpoints(client):
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").json() == {"status": "ok", "database": "ok"}


def test_login_and_me(client, db):
    customer = make_customer(db, email="amy@shop.test")
    login = client.post("/api/v1/auth/login", json={"email": "amy@shop.test", "password": "pw-12345678"})
    assert login.status_code == 200
    assert login.json()["token"] == customer.token
    assert client.get("/api/v1/me", headers=customer.headers).json()["email"] == "amy@shop.test"
    assert client.get("/api/v1/me").status_code == 401


def test_product_listing(client, db):
    make_product(db, name="Desk lamp")
    names = [p["name"] for p in client.get("/api/v1/products").json()]
    assert names == ["Desk lamp"]
