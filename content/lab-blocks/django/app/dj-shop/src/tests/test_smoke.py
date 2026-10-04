"""Smoke tests visible to everyone working on the shop."""

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_health_endpoints(client):
    assert client.get("/healthz/").json() == {"status": "ok"}
    assert client.get("/readyz/").status_code == 200


def test_signup_and_me(api_client):
    resp = api_client.post("/api/signup/", {"email": "new@shop.test", "password": "pw-12345678"}, format="json")
    assert resp.status_code == 201
    assert api_client.post("/api/signup/", {"email": "new@shop.test", "password": "pw-12345678"}, format="json").status_code == 409


def test_product_page_renders(client):
    product = make_product(name="Desk lamp")
    resp = client.get(f"/products/{product.slug}/")
    assert resp.status_code == 200
    assert b"Desk lamp" in resp.content
