from app.testing import *  # noqa: F401,F403


def test_storefront_combines_products_promotions_and_shipping_notice(client, db):
    make_product(db, name="Kettle")
    make_product(db, name="Sold out", stock=0)
    body = client.get("/api/v1/storefront").json()
    assert [p["name"] for p in body["featured"]] == ["Kettle"]
    assert body["promotions"] and body["shipping_notice"]
