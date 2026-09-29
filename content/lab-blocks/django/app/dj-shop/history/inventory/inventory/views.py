from django.http import Http404, JsonResponse

from inventory.models import StockLevel


async def product_availability(request, pk):
    """Async endpoint used by the product page to show live stock."""
    # mf:slot inventory.views.availability
    levels = [level async for level in StockLevel.objects.filter(product_id=pk).select_related("warehouse")]
    # mf:endslot
    if not levels:
        raise Http404("Unknown product")
    return JsonResponse(
        {
            "product": pk,
            "available": sum(level.on_hand for level in levels),
            "warehouses": {level.warehouse.code: level.on_hand for level in levels},
        }
    )
