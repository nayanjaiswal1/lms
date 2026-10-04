from datetime import timedelta
from decimal import Decimal

from django.db.models import Count, DecimalField, OuterRef, Subquery, Sum
from django.db.models.functions import Coalesce, TruncDate

from catalog.models import Product
from core.clock import now
from core.timeutils import day_bounds
from orders.models import Order, OrderItem

REVENUE_STATUSES = ["paid", "shipped", "delivered"]


def daily_revenue(start_day, end_day):
    """Revenue per business day for [start_day, end_day] inclusive, as (date, total, orders)."""
    start, _ = day_bounds(start_day)
    _, end = day_bounds(end_day)
    # mf:slot reports.daily.bucket
    day = TruncDate("created_at")
    # mf:endslot
    rows = (
        Order.objects.filter(status__in=REVENUE_STATUSES, created_at__gte=start, created_at__lt=end)
        .annotate(day=day)
        .values("day")
        .annotate(total=Sum("total"), orders=Count("id"))
        .order_by("day")
    )
    return [(r["day"], r["total"], r["orders"]) for r in rows]


def product_stats(limit=50):
    """Units, revenue and review counts per product."""
    zero = Decimal("0.00")
    # mf:slot reports.revenue.product_stats
    sold = OrderItem.objects.filter(product=OuterRef("pk"), order__status__in=REVENUE_STATUSES).values("product")
    units = Subquery(sold.annotate(n=Sum("quantity")).values("n"))
    revenue = Subquery(sold.annotate(n=Sum("line_total")).values("n"), output_field=DecimalField())
    reviews = Subquery(
        Product.all_objects.filter(pk=OuterRef("pk")).values("pk").annotate(n=Count("reviews")).values("n")
    )
    qs = Product.objects.annotate(
        units_sold=Coalesce(units, 0),
        revenue=Coalesce(revenue, zero, output_field=DecimalField()),
        reviews_total=Coalesce(reviews, 0),
    )
    # mf:endslot
    return list(qs.order_by("-revenue", "pk")[:limit])


def dashboard_context():
    """Numbers for the staff dashboard."""
    since = now() - timedelta(days=30)
    recent_qs = Order.objects.filter(created_at__gte=since).select_related("customer").order_by("-created_at", "-id")
    # mf:slot reports.dashboard.recent
    recent = list(recent_qs[:20])
    recent_count = len(recent)
    has_recent = bool(recent)
    # mf:endslot
    by_status = dict(Order.objects.values_list("status").annotate(n=Count("id")).order_by("status"))
    paid = Order.objects.filter(status__in=REVENUE_STATUSES).aggregate(
        total=Coalesce(Sum("total"), Decimal("0.00")), n=Count("id")
    )
    return {
        "recent_orders": recent,
        "recent_count": recent_count,
        "has_recent": has_recent,
        "by_status": by_status,
        "revenue_total": paid["total"],
        "paid_orders": paid["n"],
    }
