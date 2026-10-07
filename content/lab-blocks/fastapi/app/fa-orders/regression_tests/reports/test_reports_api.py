from app.testing import *  # noqa: F401,F403


def test_sales_report_counts_only_paid_orders_per_utc_day(client, db):
    staff = make_staff(db)
    customer = make_customer(db)
    product = make_product(db, price_cents=1000)
    make_order(db, customer, lines=[(product, 2)], status="paid")
    make_order(db, customer, lines=[(product, 1)], status="paid")
    make_order(db, customer, lines=[(product, 5)], status="pending")
    make_order(db, customer, lines=[(product, 5)], status="refunded")
    today = db.one("SELECT (now() AT TIME ZONE 'UTC')::date")
    rows = client.get("/api/v1/staff/reports/sales", headers=staff.headers).json()
    assert rows == [{"day": str(today), "orders": 2, "revenue_cents": 3000}]


def test_sales_report_window_excludes_older_orders(client, db):
    staff = make_staff(db)
    customer = make_customer(db)
    product = make_product(db, price_cents=1000)
    old = make_order(db, customer, lines=[(product, 1)], status="paid")
    db.execute("UPDATE orders SET created_at = now() - interval '30 days' WHERE id = %s", old)
    make_order(db, customer, lines=[(product, 1)], status="paid")
    week = client.get("/api/v1/staff/reports/sales", params={"days": 7}, headers=staff.headers).json()
    year = client.get("/api/v1/staff/reports/sales", params={"days": 90}, headers=staff.headers).json()
    assert sum(r["orders"] for r in week) == 1
    assert sum(r["orders"] for r in year) == 2
    assert [r["day"] for r in year] == sorted(r["day"] for r in year)


def test_sales_report_validates_the_window_and_is_staff_only(client, db):
    staff = make_staff(db)
    customer = make_customer(db)
    assert client.get("/api/v1/staff/reports/sales", params={"days": 0}, headers=staff.headers).status_code == 422
    assert client.get("/api/v1/staff/reports/sales", headers=customer.headers).status_code == 403
    assert client.get("/api/v1/staff/reports/sales").status_code == 401
