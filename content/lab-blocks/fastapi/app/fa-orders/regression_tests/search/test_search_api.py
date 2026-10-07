from app.testing import *  # noqa: F401,F403


def _names(client, q, **params):
    response = client.get("/api/v1/products/search", params={"q": q, **params})
    assert response.status_code == 200
    return [p["name"] for p in response.json()]


def test_search_matches_names_and_skus_case_insensitively(client, db):
    make_product(db, name="Desk Lamp", sku="LMP-0001")
    make_product(db, name="Floor lamp", sku="LMP-0002")
    make_product(db, name="Kettle", sku="KIT-0001")
    assert _names(client, "LAMP") == ["Desk Lamp", "Floor lamp"]
    assert _names(client, "kit-00") == ["Kettle"]
    assert _names(client, "nothing-like-this") == []


def test_search_skips_inactive_products_and_honours_the_limit(client, db):
    for n in range(4):
        make_product(db, name=f"Shelf {n}")
    make_product(db, name="Shelf retired", is_active=False)
    assert _names(client, "shelf", limit=2) == ["Shelf 0", "Shelf 1"]
    assert "Shelf retired" not in _names(client, "shelf")


def test_search_treats_wildcards_literally(client, db):
    make_product(db, name="100% cotton rug")
    make_product(db, name="Plain rug")
    make_product(db, name="snake_case mug")
    assert _names(client, "100%") == ["100% cotton rug"]
    assert _names(client, "e_c") == ["snake_case mug"]


def test_search_needs_at_least_two_characters(client, db):
    assert client.get("/api/v1/products/search", params={"q": "a"}).status_code == 422
    assert client.get("/api/v1/products/search").status_code == 422


def test_search_expands_synonyms(client, db):
    make_product(db, name="Corner sofa")
    make_product(db, name="Kettle")
    assert _names(client, "couch") == ["Corner sofa"]
