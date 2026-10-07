"""GET /api/reports/order-summary: how many orders the signed-in customer has per status, and what they spent."""

from fastapi import APIRouter, Depends, FastAPI

from ..auth import current_user
from ..deps import get_store
from ..store import Store

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/order-summary")
def order_summary(user: dict = Depends(current_user), store: Store = Depends(get_store)) -> dict:
    orders = store.orders_for(user["id"])
    by_status: dict[str, int] = {}
    for order in orders:
        by_status[order["status"]] = by_status.get(order["status"], 0) + 1
    return {"orders": len(orders), "by_status": by_status, "spent_cents": sum(o["total_cents"] for o in orders)}


def register(app: FastAPI) -> None:
    app.include_router(router, prefix="/api")
