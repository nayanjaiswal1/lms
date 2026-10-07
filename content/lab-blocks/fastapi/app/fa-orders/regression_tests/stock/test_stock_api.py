from app.testing import *  # noqa: F401,F403


def test_staff_can_add_and_remove_units(client, db):
    staff = make_staff(db)
    product = make_product(db, stock=10)
    added = client.post(f"/api/v1/staff/products/{product.id}/stock", json={"delta": 5}, headers=staff.headers)
    removed = client.post(f"/api/v1/staff/products/{product.id}/stock", json={"delta": -12}, headers=staff.headers)
    assert added.json() == {"product_id": product.id, "stock": 15}
    assert removed.json() == {"product_id": product.id, "stock": 3}
    assert db.one("SELECT stock FROM products WHERE id = %s", product.id) == 3


def test_stock_never_goes_below_zero(client, db):
    staff = make_staff(db)
    product = make_product(db, stock=3)
    response = client.post(f"/api/v1/staff/products/{product.id}/stock", json={"delta": -4}, headers=staff.headers)
    assert response.status_code == 409
    assert db.one("SELECT stock FROM products WHERE id = %s", product.id) == 3
    exact = client.post(f"/api/v1/staff/products/{product.id}/stock", json={"delta": -3}, headers=staff.headers)
    assert exact.json()["stock"] == 0


def test_unknown_products_and_non_staff_callers_are_rejected(client, db):
    staff = make_staff(db)
    customer = make_customer(db)
    product = make_product(db, stock=3)
    assert client.post("/api/v1/staff/products/999999/stock", json={"delta": 1}, headers=staff.headers).status_code == 409
    assert client.post(f"/api/v1/staff/products/{product.id}/stock", json={"delta": 1}, headers=customer.headers).status_code == 403
    assert client.post(f"/api/v1/staff/products/{product.id}/stock", json={"delta": 1}).status_code == 401
    assert db.one("SELECT stock FROM products WHERE id = %s", product.id) == 3
