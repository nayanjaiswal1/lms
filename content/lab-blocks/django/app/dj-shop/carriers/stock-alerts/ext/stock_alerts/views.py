from django.conf import settings
from django.db.models import Sum
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response

from catalog.models import Product


@api_view(["GET"])
@permission_classes([IsAdminUser])
def stock_alerts(request):
    """Products whose total stock is under the low-stock threshold."""
    low = (
        Product.objects.annotate(stock=Sum("stock_levels__on_hand"))
        .filter(stock__lt=settings.LOW_STOCK_THRESHOLD)
        .order_by("stock", "sku")
    )
    return Response({"threshold": settings.LOW_STOCK_THRESHOLD, "items": [{"sku": p.sku, "stock": p.stock} for p in low]})
