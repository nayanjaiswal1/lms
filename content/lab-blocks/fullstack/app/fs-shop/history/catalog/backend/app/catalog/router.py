from fastapi import APIRouter, Depends, Query

from ..deps import get_store
from ..store import Store

router = APIRouter(prefix="/products", tags=["catalog"])


@router.get("")
def search_products(q: str = Query("", max_length=100), store: Store = Depends(get_store)) -> dict:
    """Products whose name or SKU contains `q` (case-insensitive); everything when `q` is empty."""
    needle = q.strip().casefold()
    items = [
        product
        for product in store.products.values()
        if needle in product["name"].casefold() or needle in product["sku"].casefold()
    ]
    return {"items": sorted(items, key=lambda product: product["id"])}
