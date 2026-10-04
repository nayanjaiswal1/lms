"""PATCH /me changes only the fields that were sent; an explicit null still clears a field."""

from app.testing import *  # noqa: F401,F403


def test_patch_leaves_unsent_fields_alone(client, db):
    customer = make_customer(db, phone="+15550100", company="Acme Ltd", notes="Prefers email")
    response = client.patch("/api/v1/me", json={"phone": "+15550199"}, headers=customer.headers)
    assert response.status_code == 200
    assert response.json()["phone"] == "+15550199"
    assert response.json()["company"] == "Acme Ltd"
    assert response.json()["notes"] == "Prefers email"
    assert db.one("SELECT company FROM customers WHERE id = %s", customer.id) == "Acme Ltd"


def test_patch_with_an_explicit_null_clears_the_field(client, db):
    customer = make_customer(db, phone="+15550100", company="Acme Ltd")
    response = client.patch("/api/v1/me", json={"company": None}, headers=customer.headers)
    assert response.status_code == 200
    assert response.json()["company"] is None
    assert response.json()["phone"] == "+15550100"
