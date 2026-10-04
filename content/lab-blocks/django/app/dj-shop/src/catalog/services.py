from django.core.cache import cache
from django.db.models import Sum

from core import metrics

TOP_PRODUCTS_KEY = "catalog:top-products"
TOP_PRODUCTS_TTL = 300
LOCK_TTL = 30


def compute_top_products(limit=10):
    """The expensive part: best sellers by units ordered."""
    from orders.models import OrderItem

    metrics.incr("catalog.top_products.recompute")
    rows = (
        OrderItem.objects.values("product_id", "product__name")
        .annotate(units=Sum("quantity"))
        .order_by("-units", "product_id")[:limit]
    )
    return [{"id": r["product_id"], "name": r["product__name"], "units": r["units"]} for r in rows]


def get_top_products():
    """Cached best sellers; only one caller recomputes an expired entry."""
    # mf:slot catalog.cache.top_products
    data = cache.get(TOP_PRODUCTS_KEY)
    if data is not None:
        return data
    if cache.add(TOP_PRODUCTS_KEY + ":lock", 1, LOCK_TTL):
        try:
            data = compute_top_products()
            cache.set(TOP_PRODUCTS_KEY, data, TOP_PRODUCTS_TTL)
        finally:
            cache.delete(TOP_PRODUCTS_KEY + ":lock")
        return data
    return cache.get(TOP_PRODUCTS_KEY) or []
    # mf:endslot
