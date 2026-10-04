from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db
QUOTE = chr(39)


def test_product_list_page_and_pagination(client):
    category = make_category("Lamps")
    for i in range(30):
        make_product(name=f"Lamp {i:02d}", category=category)
    assert client.get("/").status_code == 200
    assert client.get("/?page=2").status_code == 200


def test_product_list_api_is_paginated(api_client):
    category = make_category()
    for _ in range(30):
        make_product(category=category)
    body = api_client.get("/api/products/").json()
    assert body["count"] == 30 and len(body["results"]) == 25
    assert body["next"]


def test_category_filter(api_client):
    a, b = make_category("A"), make_category("B")
    make_product(category=a)
    make_product(category=b)
    assert api_client.get(f"/api/products/?category={a.slug}").json()["count"] == 1


def test_soft_deleted_products_are_hidden_everywhere(client, api_client):
    category = make_category("Chairs")
    live = make_product(name="Live chair", category=category)
    gone = make_product(name="Gone chair", category=category)
    gone.soft_delete()
    assert [p["id"] for p in api_client.get("/api/products/").json()["results"]] == [live.pk]
    page = client.get(f"/categories/{category.slug}/")
    assert b"Live chair" in page.content and b"Gone chair" not in page.content
    assert client.get(f"/products/{gone.slug}/").status_code == 404


def test_product_detail_shows_rating_summary(client):
    product = make_product(review_count=2, rating_total=9)
    assert b"4.5 / 5 from 2 reviews" in client.get(f"/products/{product.slug}/").content


def test_product_name_fits_column():
    from catalog.models import Product

    assert Product._meta.get_field("name").max_length == 120


@needs_postgres
def test_search_matches_and_is_injection_safe(api_client):
    make_product(name="Oak desk", sku="DESK-1")
    make_product(name="Pine shelf", sku="SHELF-1")
    found = api_client.get("/api/products/search/", {"q": "desk"}).json()["results"]
    assert [p["sku"] for p in found] == ["DESK-1"]
    hostile = f"x{QUOTE} OR {QUOTE}1{QUOTE}={QUOTE}1"
    for term in [QUOTE, hostile, f"%{QUOTE}; DROP TABLE catalog_product; --"]:
        assert api_client.get("/api/products/search/", {"q": term}).status_code == 200
    assert api_client.get("/api/products/search/", {"q": hostile}).json()["results"] == []


@needs_postgres
def test_search_excludes_soft_deleted(api_client):
    make_product(name="Hidden gem", sku="H-1").soft_delete()
    assert api_client.get("/api/products/search/", {"q": "gem"}).json()["results"] == []


def test_product_price_is_exact_decimal():
    from decimal import Decimal

    from catalog.models import Product

    product = make_product(price="19.99")
    stored = Product.objects.get(pk=product.pk).price
    assert stored == Decimal("19.99") and isinstance(stored, Decimal)
