from app.testing import *  # noqa: F401,F403


def test_feed_lists_active_products_without_authentication(client, db):
    make_product(db, name="Desk lamp", sku="LMP-1", price_cents=2599, stock=4)
    make_product(db, name="Kettle", sku="KIT-1", price_cents=3999, stock=0)
    make_product(db, name="Retired", sku="OLD-1", is_active=False)
    body = client.get("/feeds/products.json").json()
    assert body["products"] == [
        {"sku": "LMP-1", "name": "Desk lamp", "price_cents": 2599, "in_stock": True},
        {"sku": "KIT-1", "name": "Kettle", "price_cents": 3999, "in_stock": False},
    ]
