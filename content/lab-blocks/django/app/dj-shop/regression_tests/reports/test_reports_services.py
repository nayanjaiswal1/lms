from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db
NY = ZoneInfo("America/New_York")


def _order(user, product, local_dt, qty=1, status="paid"):
    from orders.models import Order, OrderItem

    total = product.price * qty
    order = Order.objects.create(customer=user, status=status, subtotal=total, total=total, created_at=local_dt)
    OrderItem.objects.create(order=order, product=product, quantity=qty, unit_price=product.price, line_total=total)
    return order


def test_only_revenue_statuses_are_counted():
    from reports.services import daily_revenue

    user, product = make_customer(), make_product("10.00")
    _order(user, product, datetime(2025, 3, 5, 12, tzinfo=NY), status="cancelled")
    _order(user, product, datetime(2025, 3, 5, 13, tzinfo=NY), status="refunded")
    assert daily_revenue(date(2025, 3, 5), date(2025, 3, 5)) == []


def test_product_stats_are_not_inflated_by_joins():
    from reports.services import product_stats
    from reviews.models import Review

    buyer = make_customer()
    product = make_product("10.00")
    for _ in range(3):
        _order(buyer, product, datetime(2025, 3, 6, 12, tzinfo=NY), qty=2)
    for _ in range(4):
        Review.objects.create(product=product, customer=make_customer(), rating=5)
    (row,) = [r for r in product_stats() if r.pk == product.pk]
    assert row.units_sold == 6 and row.revenue == Decimal("60.00") and row.reviews_total == 4


def test_dashboard_is_staff_only(client):
    client.force_login(make_customer())
    assert client.get("/staff/dashboard/").status_code == 302


def test_revenue_api(fake_payments):
    from orders import services

    product = make_product("10.00")
    make_stock(product, 5)
    services.place_order(make_customer(), [(product, 2)])
    body = authed(make_staff()).get("/api/reports/revenue/").json()
    assert body["products"][0]["units"] == 2 and body["products"][0]["revenue"] == "20.00"
    assert authed(make_customer()).get("/api/reports/revenue/").status_code == 403
    assert authed(make_staff()).get("/api/reports/revenue/?from=nope").status_code == 400


def test_dashboard_lists_recent_orders_for_staff(client):
    from django.utils import timezone

    buyer, boss = make_customer(), make_staff()
    for _ in range(3):
        _order(buyer, make_product(), timezone.now())
    client.force_login(boss)
    resp = client.get("/staff/dashboard/")
    assert resp.status_code == 200 and b"Last 30 days (3 orders)" in resp.content
    assert resp.content.count(buyer.email.encode()) == 3
