from app.testing import *  # noqa: F401,F403


def _place(client, customer, product, quantity=1, shipping_name="Amy Archer"):
    return client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": product.id, "quantity": quantity}], "shipping_name": shipping_name},
        headers=customer.headers,
    )


def test_placing_an_order_reserves_stock_and_totals_the_lines(client, db):
    customer = make_customer(db)
    lamp = make_product(db, price_cents=1500, stock=10)
    kettle = make_product(db, price_cents=2000, stock=5)
    response = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": lamp.id, "quantity": 2}, {"product_id": kettle.id, "quantity": 1}]},
        headers=customer.headers,
    )
    assert response.status_code == 201
    body = response.json()
    assert body["total_cents"] == 5000
    assert body["status"] == "pending"
    assert sorted(item["quantity"] for item in body["items"]) == [1, 2]
    assert db.one("SELECT stock FROM products WHERE id = %s", lamp.id) == 8
    assert db.one("SELECT stock FROM products WHERE id = %s", kettle.id) == 4


def test_ordering_more_than_the_stock_is_rejected_and_changes_nothing(client, db):
    customer = make_customer(db)
    product = make_product(db, stock=2)
    response = _place(client, customer, product, quantity=3)
    assert response.status_code == 409
    assert db.one("SELECT stock FROM products WHERE id = %s", product.id) == 2
    assert db.one("SELECT count(*) FROM orders") == 0


def test_unknown_and_inactive_products_are_rejected(client, db):
    customer = make_customer(db)
    inactive = make_product(db, is_active=False)
    assert _place(client, customer, inactive).status_code == 422
    missing = client.post(
        "/api/v1/orders", json={"items": [{"product_id": 999999, "quantity": 1}]}, headers=customer.headers
    )
    assert missing.status_code == 422


def test_order_validation(client, db):
    customer = make_customer(db)
    product = make_product(db)
    assert client.post("/api/v1/orders", json={"items": []}, headers=customer.headers).status_code == 422
    assert _place(client, customer, product, quantity=0).status_code == 422
    assert client.post("/api/v1/orders", json={"items": [{"product_id": product.id, "quantity": 1}]}).status_code == 401


def test_the_order_list_returns_every_order_of_the_customer_newest_first(client, db):
    customer = make_customer(db)
    other = make_customer(db)
    product = make_product(db, price_cents=700)
    ids = [make_order(db, customer, lines=[(product, 1), (product, 2)]) for _ in range(6)]
    make_order(db, other, lines=[(product, 1)])
    body = client.get("/api/v1/orders", headers=customer.headers).json()
    assert [o["id"] for o in body] == sorted(ids, reverse=True)
    assert all(len(o["items"]) == 2 for o in body)
    assert body[0]["items"][0]["product_name"] == product.name
    assert len(client.get("/api/v1/orders", params={"limit": 2}, headers=customer.headers).json()) == 2


def test_a_customer_reads_their_own_order(client, db):
    customer = make_customer(db)
    product = make_product(db)
    mine = make_order(db, customer, lines=[(product, 3)])
    body = client.get(f"/api/v1/orders/{mine}", headers=customer.headers).json()
    assert body["id"] == mine
    assert body["items"][0]["quantity"] == 3
    assert client.get("/api/v1/orders/999999", headers=customer.headers).status_code == 404
    assert client.get(f"/api/v1/orders/{mine}").status_code == 401
