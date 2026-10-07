from fastapi.testclient import TestClient

from backend.app.main import create_app


def names(client, **params):
    return [p["name"] for p in client.get("/api/products", params=params).json()["items"]]


def test_empty_query_lists_every_product():
    assert len(names(TestClient(create_app()), q="")) == 12


def test_search_matches_name_case_insensitively():
    assert names(TestClient(create_app()), q="mOuSe") == ["Wireless Mouse"]


def test_search_matches_sku():
    assert names(TestClient(create_app()), q="kb-100") == ["Mechanical Keyboard"]


def test_special_characters_in_a_properly_encoded_query_are_matched_literally():
    client = TestClient(create_app())
    assert names(client, q="R&D") == ["R&D Kit"]
    assert names(client, q="+ Mic") == ["Headset + Mic"]


def test_no_match_is_an_empty_list():
    assert names(TestClient(create_app()), q="zzz") == []


def test_products_expose_price_and_stock():
    product = TestClient(create_app()).get("/api/products", params={"q": "cable"}).json()["items"][0]
    assert (product["price_cents"], product["stock"]) == (1250, 100)
