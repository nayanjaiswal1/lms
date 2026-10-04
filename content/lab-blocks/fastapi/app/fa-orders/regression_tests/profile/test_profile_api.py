from app.testing import *  # noqa: F401,F403


def test_patch_updates_the_fields_that_are_sent(client, db):
    customer = make_customer(db)
    response = client.patch(
        "/api/v1/me",
        json={"phone": "+15550199", "company": "Acme Ltd", "notes": "Prefers email"},
        headers=customer.headers,
    )
    assert response.status_code == 200
    assert response.json()["phone"] == "+15550199"
    assert response.json()["company"] == "Acme Ltd"
    assert db.one("SELECT notes FROM customers WHERE id = %s", customer.id) == "Prefers email"
    assert client.get("/api/v1/me", headers=customer.headers).json()["company"] == "Acme Ltd"


def test_patch_with_an_explicit_null_clears_the_field(client, db):
    customer = make_customer(db, phone="+15550100", company="Acme Ltd", notes="Prefers email")
    response = client.patch("/api/v1/me", json={"company": None, "phone": None, "notes": None}, headers=customer.headers)
    assert response.status_code == 200
    assert (response.json()["company"], response.json()["phone"], response.json()["notes"]) == (None, None, None)
    assert db.one("SELECT company FROM customers WHERE id = %s", customer.id) is None


def test_patch_never_touches_the_identity_fields(client, db):
    customer = make_customer(db, email="amy@shop.test")
    response = client.patch("/api/v1/me", json={"email": "evil@shop.test", "is_staff": True}, headers=customer.headers)
    assert response.status_code == 200
    assert response.json()["email"] == "amy@shop.test"
    assert response.json()["is_staff"] is False


def test_patch_validates_lengths_and_needs_a_token(client, db):
    customer = make_customer(db)
    assert client.patch("/api/v1/me", json={"phone": "1" * 33}, headers=customer.headers).status_code == 422
    assert client.patch("/api/v1/me", json={"phone": "+15550100"}).status_code == 401
