import math

from fastapi import APIRouter, Depends, Query

from ..auth import current_user
from ..config import Settings
from ..deps import get_settings, get_store
from ..errors import ApiError
from ..store import Store
from .serializers import serialize_order

router = APIRouter(prefix="/orders", tags=["orders"])


@router.get("")
def list_orders(
    page: int = Query(1, ge=1),
    page_size: int | None = Query(None, ge=1),
    user: dict = Depends(current_user),
    store: Store = Depends(get_store),
    settings: Settings = Depends(get_settings),
) -> dict:
    """The signed-in customer's orders, newest first. `page` starts at 1."""
    size = min(page_size or settings.default_page_size, settings.max_page_size)
    mine = store.orders_for(user["id"])
    # mf:slot orders.page.offset
    offset = (page - 1) * size
    # mf:endslot
    return {
        "items": [serialize_order(order) for order in mine[offset : offset + size]],
        "page": page,
        "pages": max(1, math.ceil(len(mine) / size)),
        "total": len(mine),
    }


@router.get("/{order_id}")
def get_order(order_id: int, user: dict = Depends(current_user), store: Store = Depends(get_store)) -> dict:
    order = next((o for o in store.orders_for(user["id"]) if o["id"] == order_id), None)
    if order is None:
        raise ApiError(404, "order_not_found", "No such order.")
    return {**serialize_order(order), "items": order["items"]}
