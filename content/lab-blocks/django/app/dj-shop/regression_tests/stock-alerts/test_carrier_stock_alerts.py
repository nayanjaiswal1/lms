from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_alerts_list_low_stock_for_staff_only():
    low, plenty = make_product(sku="ALERT-LOW"), make_product(sku="ALERT-OK")
    make_stock(low, 2)
    make_stock(plenty, 300)
    body = authed(make_staff()).get("/api/staff/stock-alerts/").json()
    assert [i["sku"] for i in body["items"]] == ["ALERT-LOW"]
    assert authed(make_customer()).get("/api/staff/stock-alerts/").status_code == 403
