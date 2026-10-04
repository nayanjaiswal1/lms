from app.testing import *  # noqa: F401,F403


def _paid_order(db, customer):
    order_id = make_order(db, customer, lines=[(make_product(db), 1)], status="paid")
    db.execute(
        "INSERT INTO payments (order_id, provider_charge_id, status, amount_cents) VALUES (%s, %s, %s, %s)",
        order_id,
        "ch_1",
        "succeeded",
        1000,
    )
    return order_id


def test_timeline_shows_placed_and_paid(client, db):
    customer = make_customer(db)
    order_id = _paid_order(db, customer)
    body = client.get(f"/api/v1/orders/{order_id}/timeline", headers=customer.headers).json()
    assert body["order_id"] == order_id
    assert body["status"] == "paid"
    assert [e["event"] for e in body["events"]] == ["placed", "paid"]


def test_timeline_of_a_refunded_order_ends_with_the_refund(client, db):
    customer = make_customer(db)
    order_id = _paid_order(db, customer)
    db.execute("UPDATE orders SET status = 'refunded' WHERE id = %s", order_id)
    events = client.get(f"/api/v1/orders/{order_id}/timeline", headers=customer.headers).json()["events"]
    assert [e["event"] for e in events] == ["placed", "paid", "refunded"]


def test_timeline_of_a_pending_order_only_has_the_placement(client, db):
    customer = make_customer(db)
    order_id = make_order(db, customer, lines=[(make_product(db), 1)])
    events = client.get(f"/api/v1/orders/{order_id}/timeline", headers=customer.headers).json()["events"]
    assert [e["event"] for e in events] == ["placed"]


def test_timeline_is_private_to_the_owner(client, db):
    owner = make_customer(db)
    stranger = make_customer(db)
    order_id = make_order(db, owner, lines=[(make_product(db), 1)])
    assert client.get(f"/api/v1/orders/{order_id}/timeline", headers=stranger.headers).status_code == 404
    assert client.get(f"/api/v1/orders/{order_id}/timeline").status_code == 401
    assert client.get("/api/v1/orders/999999/timeline", headers=owner.headers).status_code == 404
