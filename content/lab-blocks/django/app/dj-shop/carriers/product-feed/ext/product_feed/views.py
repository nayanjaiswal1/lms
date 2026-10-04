from django.http import JsonResponse

from catalog.models import Product


def product_feed(request):
    """Public feed of live products for partner sites."""
    items = [
        {"sku": p.sku, "name": p.name, "price": str(p.price), "url": request.build_absolute_uri(f"/products/{p.slug}/")}
        for p in Product.objects.order_by("sku")
    ]
    return JsonResponse({"count": len(items), "items": items})
