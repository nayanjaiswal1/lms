from app.testing import *  # noqa: F401,F403


def test_alerts_list_active_products_below_the_threshold_lowest_first(client, db):
    staff = make_staff(db)
    low = make_product(db, name="Low", stock=2)
    lower = make_product(db, name="Lower", stock=0)
    make_product(db, name="Plenty", stock=50)
    make_product(db, name="Retired", stock=1, is_active=False)
    body = client.get("/api/v1/staff/stock-alerts", headers=staff.headers).json()
    assert body["threshold"] == 10
    assert [(p["id"], p["stock"]) for p in body["products"]] == [(lower.id, 0), (low.id, 2)]
    custom = client.get("/api/v1/staff/stock-alerts", params={"threshold": 100}, headers=staff.headers).json()
    assert len(custom["products"]) == 3


def test_alerts_are_staff_only_and_validate_the_threshold(client, db):
    staff = make_staff(db)
    customer = make_customer(db)
    assert client.get("/api/v1/staff/stock-alerts", headers=customer.headers).status_code == 403
    assert client.get("/api/v1/staff/stock-alerts").status_code == 401
    assert client.get("/api/v1/staff/stock-alerts", params={"threshold": -1}, headers=staff.headers).status_code == 422
