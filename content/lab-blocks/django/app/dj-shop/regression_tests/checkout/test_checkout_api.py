from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db
ITEM = "items"


def _stocked(price="10.00", qty=20):
    product = make_product(price)
    make_stock(product, qty)
    return product


def _body(product, quantity=1):
    return {"items": [{"product": product.pk, "quantity": quantity}]}


def test_place_order_via_api(fake_payments):
    user = make_customer()
    product = _stocked()
    resp = authed(user).post("/api/orders/", _body(product, 2), format="json")
    assert resp.status_code == 201
    body = resp.json()
    assert body["items_count"] == 1 and body["total"] == "21.65" and body["status"] == "paid"


def test_order_api_error_mapping(fake_payments):
    from payments.client import PaymentContractError, TransientPaymentError

    user = make_customer()
    product = _stocked(qty=1)
    client = authed(user)
    assert client.post("/api/orders/", _body(product, 5), format="json").status_code == 409
    unknown = {"items": [{"product": 424242, "quantity": 1}]}
    assert client.post("/api/orders/", unknown, format="json").status_code == 400
    assert client.post("/api/orders/", {"items": []}, format="json").status_code == 400
    fake_payments.status = "declined"
    assert client.post("/api/orders/", _body(product), format="json").status_code == 402
    fake_payments.status = "succeeded"
    fake_payments.error = PaymentContractError("shape")
    assert client.post("/api/orders/", _body(product), format="json").status_code == 502
    fake_payments.error = TransientPaymentError("down")
    assert client.post("/api/orders/", _body(product), format="json").status_code == 503


def test_my_orders_lists_only_orders_placed_by_me(fake_payments):
    from orders.models import Order

    me, other = make_customer(), make_customer()
    product = _stocked()
    mine = authed(me).post("/api/orders/", _body(product), format="json").json()
    theirs = authed(other).post("/api/orders/", _body(product), format="json").json()
    Order.objects.filter(pk=theirs["id"]).update(handled_by=me)
    ids = [o["id"] for o in authed(me).get("/api/orders/").json()["results"]]
    assert ids == [mine["id"]]
    assert [o.pk for o in me.handled_orders.all()] == [theirs["id"]]
    assert [o.pk for o in me.orders.all()] == [mine["id"]]


def test_order_list_is_paginated(fake_payments):
    user = make_customer()
    product = _stocked(qty=100)
    client = authed(user)
    for _ in range(3):
        client.post("/api/orders/", _body(product), format="json")
    body = client.get("/api/orders/?page_size=2").json()
    assert body["count"] == 3 and len(body["results"]) == 2


def test_order_detail_and_cancel_are_scoped_to_owner(fake_payments):
    owner, intruder = make_customer(), make_customer()
    product = _stocked()
    order = authed(owner).post("/api/orders/", _body(product), format="json").json()
    assert authed(intruder).get(f"/api/orders/{order['id']}/").status_code == 404
    assert authed(intruder).post(f"/api/orders/{order['id']}/cancel/").status_code == 404
    assert authed(owner).post(f"/api/orders/{order['id']}/cancel/").json()["status"] == "cancelled"
    assert authed(owner).post(f"/api/orders/{order['id']}/cancel/").status_code == 409
