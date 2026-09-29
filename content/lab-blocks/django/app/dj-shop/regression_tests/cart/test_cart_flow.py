from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_add_item_accumulates_quantity():
    user = make_customer()
    product = make_product()
    make_stock(product, 10)
    client = authed(user)
    assert client.post("/api/cart/items/", {"product": product.pk, "quantity": 2}, format="json").status_code == 201
    body = client.post("/api/cart/items/", {"product": product.pk, "quantity": 3}, format="json").json()
    assert body["items"][0]["quantity"] == 5


def test_add_item_refuses_more_than_stock():
    user = make_customer()
    product = make_product()
    make_stock(product, 2)
    resp = authed(user).post("/api/cart/items/", {"product": product.pk, "quantity": 3}, format="json")
    assert resp.status_code == 409


def test_cart_requires_login(api_client):
    assert api_client.get("/api/cart/").status_code in (401, 403)


def test_clear_cart():
    user = make_customer()
    product = make_product()
    make_stock(product, 5)
    client = authed(user)
    client.post("/api/cart/items/", {"product": product.pk, "quantity": 1}, format="json")
    assert client.delete("/api/cart/").status_code == 204
    assert client.get("/api/cart/").json()["items"] == []


def test_cart_page_renders_lines(client):
    user = make_customer()
    product = make_product(name="Cart lamp")
    make_stock(product, 5)
    authed(user).post("/api/cart/items/", {"product": product.pk, "quantity": 1}, format="json")
    client.force_login(user)
    assert b"Cart lamp" in client.get("/cart/").content
