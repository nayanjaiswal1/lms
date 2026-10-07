"""GET /api/reports/low-stock?threshold=N: products with at most N units left, fewest first."""

from fastapi import APIRouter, Depends, FastAPI, Query

from ..deps import get_store
from ..store import Store

DEFAULT_THRESHOLD = 5

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/low-stock")
def low_stock(threshold: int = Query(DEFAULT_THRESHOLD, ge=0), store: Store = Depends(get_store)) -> dict:
    items = [p for p in store.products.values() if p["stock"] <= threshold]
    return {"items": sorted(items, key=lambda p: (p["stock"], p["id"]))}


def register(app: FastAPI) -> None:
    app.include_router(router, prefix="/api")
