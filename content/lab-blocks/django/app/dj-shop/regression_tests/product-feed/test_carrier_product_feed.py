from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_feed_is_public_and_lists_live_products(client):
    live = make_product(name="Feed lamp", sku="FEED-1")
    make_product(name="Removed", sku="FEED-2").soft_delete()
    body = client.get("/feeds/products.json").json()
    assert body["count"] == 1
    assert body["items"][0]["sku"] == live.sku and body["items"][0]["url"].endswith(f"/products/{live.slug}/")
