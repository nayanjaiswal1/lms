from fastapi.testclient import TestClient

from backend.app.main import create_app


def skus(**params):
    body = TestClient(create_app()).get("/api/reports/low-stock", params=params).json()
    return [p["sku"] for p in body["items"]]


def test_default_threshold_lists_products_nearly_out_of_stock_fewest_first():
    assert skus() == ["SD-512", "MN-270"]


def test_a_custom_threshold_widens_the_list():
    assert skus(threshold=10) == ["SD-512", "MN-270", "RD-301", "WC-720"]


def test_a_negative_threshold_is_rejected():
    assert TestClient(create_app()).get("/api/reports/low-stock", params={"threshold": -1}).status_code == 422
