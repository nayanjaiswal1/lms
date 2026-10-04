import csv
import io

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_export_lists_only_my_orders_as_csv(fake_payments):
    from orders import services

    me, other = make_customer(), make_customer()
    product = make_product("10.00")
    make_stock(product, 10)
    mine = services.place_order(me, [(product, 1)])
    services.place_order(other, [(product, 1)])
    resp = authed(me).get("/api/orders/export/")
    assert resp.status_code == 200 and resp["Content-Type"].startswith("text/csv")
    rows = list(csv.DictReader(io.StringIO(resp.content.decode())))
    assert [r["id"] for r in rows] == [str(mine.pk)]
    assert rows[0]["status"] == "paid"


def test_export_requires_login(api_client):
    assert api_client.get("/api/orders/export/").status_code in (401, 403)
