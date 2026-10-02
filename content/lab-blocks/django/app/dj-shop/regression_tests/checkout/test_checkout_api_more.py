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


def test_order_list_page_lists_every_order_page_by_page(client):
    from orders.models import Order

    user = make_customer()
    orders = [Order.objects.create(customer=user, status="paid", subtotal=5, total=5) for _ in range(25)]
    client.force_login(user)
    first = client.get("/orders/").content.decode()
    second = client.get("/orders/?page=2").content.decode()
    listed = [o for o in orders if f'href="/orders/{o.pk}/"' in first]
    rest = [o for o in orders if f'href="/orders/{o.pk}/"' in second]
    assert len(listed) == 20 and len(rest) == 5
    assert {o.pk for o in listed} | {o.pk for o in rest} == {o.pk for o in orders}
