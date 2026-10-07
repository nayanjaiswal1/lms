from app.testing import *  # noqa: F401,F403


def test_overview_summarises_orders_and_wallet(client, db):
    customer = make_customer(db, credit_cents=700)
    product = make_product(db)
    make_order(db, customer, lines=[(product, 1)])
    make_order(db, customer, lines=[(product, 2)])
    make_order(db, make_customer(db), lines=[(product, 1)])
    body = client.get("/api/v1/me/overview", headers=customer.headers).json()
    assert body["orders"] == 2
    assert body["wallet_balance_cents"] == 700
    assert body["last_order_at"] is not None


def test_overview_of_a_new_customer_is_empty(client, db):
    customer = make_customer(db)
    body = client.get("/api/v1/me/overview", headers=customer.headers).json()
    assert body == {"orders": 0, "last_order_at": None, "wallet_balance_cents": 0}
    assert client.get("/api/v1/me/overview").status_code == 401
