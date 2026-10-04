"""The staff dashboard must evaluate each of its querysets once."""

from django.db import connection
from django.test.utils import CaptureQueriesContext

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_dashboard_context_evaluates_each_queryset_once():
    from orders.models import Order
    from reports.services import dashboard_context

    buyer = make_customer()
    for _ in range(5):
        Order.objects.create(customer=buyer, status="paid", subtotal=10, total=10)
    with CaptureQueriesContext(connection) as ctx:
        context = dashboard_context()
    assert context["recent_count"] == 5 and context["has_recent"] is True
    assert len(ctx) <= 3, [q["sql"][:80] for q in ctx.captured_queries]
