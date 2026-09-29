from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def _stocked(price="10.00", qty=20):
    product = make_product(price)
    make_stock(product, qty)
    return product


def _body(product, quantity=1):
    return {"items": [{"product": product.pk, "quantity": quantity}]}


def test_invoice_is_only_visible_to_its_customer(fake_payments):
    from orders.models import Invoice

    owner, intruder = make_customer(), make_customer()
    product = _stocked()
    order = authed(owner).post("/api/orders/", _body(product), format="json").json()
    invoice = Invoice.objects.get(order_id=order["id"])
    assert authed(owner).get(f"/api/invoices/{invoice.pk}/").json()["number"] == invoice.number
    assert authed(intruder).get(f"/api/invoices/{invoice.pk}/").status_code == 404


def test_staff_order_list_needs_staff_and_filters_by_status(fake_payments):
    user, boss = make_customer(), make_staff()
    product = _stocked()
    client = authed(user)
    first = client.post("/api/orders/", _body(product), format="json").json()
    client.post("/api/orders/", _body(product), format="json")
    client.post(f"/api/orders/{first['id']}/cancel/")
    assert authed(user).get("/api/staff/orders/").status_code == 403
    body = authed(boss).get("/api/staff/orders/?status=cancelled").json()
    assert body["count"] == 1 and body["results"][0]["id"] == first["id"]


def test_cart_checkout_places_order_and_empties_cart(fake_payments):
    user = make_customer()
    product = _stocked()
    client = authed(user)
    client.post("/api/cart/items/", {"product": product.pk, "quantity": 2}, format="json")
    resp = client.post("/api/cart/checkout/", {"shipping_name": "Ada"}, format="json")
    assert resp.status_code == 201 and resp.json()["shipping_name"] == "Ada"
    assert client.get("/api/cart/").json()["items"] == []
    assert client.post("/api/cart/checkout/", {}, format="json").status_code == 400


def test_order_pages_render_and_are_owner_scoped(client, fake_payments):
    from orders.models import Invoice

    owner, intruder = make_customer(), make_customer()
    product = _stocked()
    order = authed(owner).post("/api/orders/", _body(product), format="json").json()
    invoice = Invoice.objects.get(order_id=order["id"])
    client.force_login(owner)
    assert client.get("/orders/").status_code == 200
    assert client.get(f"/orders/{order['id']}/").status_code == 200
    assert client.get(f"/orders/invoices/{invoice.pk}/").status_code == 200
    client.force_login(intruder)
    assert client.get(f"/orders/{order['id']}/").status_code == 404
    assert client.get(f"/orders/invoices/{invoice.pk}/").status_code == 404


def test_order_list_page_query_count_does_not_grow(client, fake_payments, django_assert_max_num_queries):
    user = make_customer()
    product = _stocked(qty=100)
    api = authed(user)
    for _ in range(6):
        api.post("/api/orders/", _body(product), format="json")
    client.force_login(user)
    with django_assert_max_num_queries(8):
        assert client.get("/orders/").status_code == 200


def test_customers_with_orders_cannot_be_deleted():
    from django.db.models import ProtectedError

    from orders.models import Invoice, Order

    user = make_customer()
    order = Order.objects.create(customer=user, total=5, subtotal=5)
    Invoice.objects.create(order=order, number="INV-T-1", total=5)
    with pytest.raises(ProtectedError):
        user.delete()
    assert Invoice.objects.count() == 1
