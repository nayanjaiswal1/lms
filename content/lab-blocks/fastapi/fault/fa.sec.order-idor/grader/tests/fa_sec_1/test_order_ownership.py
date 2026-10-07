"""A customer can read only their own orders, however the order id is obtained."""

from app.testing import *  # noqa: F401,F403


def test_another_customers_order_is_not_found(client, db):
    owner = make_customer(db)
    stranger = make_customer(db)
    order_id = make_order(db, owner, lines=[(make_product(db), 1)])
    assert client.get(f"/api/v1/orders/{order_id}", headers=stranger.headers).status_code == 404
    assert client.get(f"/api/v1/orders/{order_id}/timeline", headers=stranger.headers).status_code == 404


def test_the_owner_can_still_read_their_order(client, db):
    owner = make_customer(db)
    order_id = make_order(db, owner, lines=[(make_product(db), 2)])
    response = client.get(f"/api/v1/orders/{order_id}", headers=owner.headers)
    assert response.status_code == 200
    assert response.json()["id"] == order_id
    assert response.json()["items"][0]["quantity"] == 2
