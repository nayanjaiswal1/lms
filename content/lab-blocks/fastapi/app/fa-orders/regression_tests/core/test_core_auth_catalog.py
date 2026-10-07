from app.testing import *  # noqa: F401,F403


def test_health_and_readiness(client):
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").json() == {"status": "ok", "database": "ok"}


def test_login_returns_the_token_and_profile(client, db):
    customer = make_customer(db, email="amy@shop.test")
    response = client.post("/api/v1/auth/login", json={"email": "AMY@shop.test", "password": "pw-12345678"})
    assert response.status_code == 200
    body = response.json()
    assert body["token"] == customer.token
    assert body["customer"]["email"] == "amy@shop.test"
    assert "password_hash" not in body["customer"]


def test_login_rejects_a_wrong_password_and_an_unknown_email(client, db):
    make_customer(db, email="amy@shop.test")
    wrong = client.post("/api/v1/auth/login", json={"email": "amy@shop.test", "password": "wrong-password"})
    unknown = client.post("/api/v1/auth/login", json={"email": "nobody@shop.test", "password": "pw-12345678"})
    assert wrong.status_code == 401
    assert unknown.status_code == 401
    assert wrong.json() == unknown.json()


def test_me_requires_a_valid_bearer_token(client, db):
    customer = make_customer(db, email="amy@shop.test")
    assert client.get("/api/v1/me").status_code == 401
    assert client.get("/api/v1/me", headers={"Authorization": "Bearer nope"}).status_code == 401
    assert client.get("/api/v1/me", headers={"Authorization": "Basic abc"}).status_code == 401
    assert client.get("/api/v1/me", headers=customer.headers).json()["email"] == "amy@shop.test"


def test_staff_endpoints_reject_regular_customers(client, db):
    customer = make_customer(db)
    staff = make_staff(db)
    assert client.get("/api/v1/staff/reports/sales", headers=customer.headers).status_code == 403
    assert client.get("/api/v1/staff/reports/sales", headers=staff.headers).status_code == 200


def test_product_listing_hides_inactive_products_and_filters_by_category(client, db):
    make_product(db, name="Desk lamp", category="lighting")
    make_product(db, name="Floor lamp", category="lighting")
    make_product(db, name="Kettle", category="kitchen")
    make_product(db, name="Retired lamp", category="lighting", is_active=False)
    names = [p["name"] for p in client.get("/api/v1/products").json()]
    assert names == ["Desk lamp", "Floor lamp", "Kettle"]
    lighting = [p["name"] for p in client.get("/api/v1/products", params={"category": "lighting"}).json()]
    assert lighting == ["Desk lamp", "Floor lamp"]


def test_product_listing_paginates(client, db):
    for n in range(5):
        make_product(db, name=f"Item {n}")
    page = client.get("/api/v1/products", params={"limit": 2, "offset": 2}).json()
    assert [p["name"] for p in page] == ["Item 2", "Item 3"]
    assert client.get("/api/v1/products", params={"limit": 0}).status_code == 422


def test_single_product_lookup(client, db):
    product = make_product(db, name="Desk lamp", price_cents=2599)
    inactive = make_product(db, name="Retired lamp", is_active=False)
    body = client.get(f"/api/v1/products/{product.id}").json()
    assert (body["name"], body["price_cents"]) == ("Desk lamp", 2599)
    assert client.get(f"/api/v1/products/{inactive.id}").status_code == 404
    assert client.get("/api/v1/products/999999").status_code == 404
