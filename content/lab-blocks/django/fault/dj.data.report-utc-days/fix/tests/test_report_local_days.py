"""The revenue report buckets orders by the business day (America/New_York), not by the UTC date."""

from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db
NY = ZoneInfo("America/New_York")


def _order(user, when):
    from orders.models import Order

    return Order.objects.create(customer=user, status="paid", subtotal=10, total=10, created_at=when)


def test_late_night_orders_count_on_their_local_day():
    from reports.services import daily_revenue

    user = make_customer()
    _order(user, datetime(2025, 3, 1, 22, 30, tzinfo=NY))  # 03:30 UTC on March 2nd
    _order(user, datetime(2025, 3, 2, 0, 15, tzinfo=NY))
    rows = daily_revenue(date(2025, 3, 1), date(2025, 3, 2))
    assert [(str(d), t, n) for d, t, n in rows] == [("2025-03-01", Decimal("10.00"), 1), ("2025-03-02", Decimal("10.00"), 1)]
