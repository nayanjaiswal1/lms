"""The API matches an encoded query literally: the product the user typed is the one returned."""

from fastapi.testclient import TestClient

from backend.app.main import create_app


def names(query):
    return [p["name"] for p in TestClient(create_app()).get("/api/products", params={"q": query}).json()["items"]]


def test_an_ampersand_query_finds_exactly_that_product():
    assert names("R&D Kit") == ["R&D Kit"]


def test_a_truncated_query_matches_more_than_the_typed_one():
    assert len(names("R")) > 1
