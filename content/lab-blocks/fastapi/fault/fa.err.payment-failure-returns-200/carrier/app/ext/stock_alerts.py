"""Staff endpoint listing the products that are running low."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.catalog.models import Product
from app.customers.deps import staff_only
from app.db import get_session

router = APIRouter(prefix="/api/v1/staff", tags=["stock-alerts"], dependencies=[Depends(staff_only)])


@router.get("/stock-alerts")
async def stock_alerts(
    threshold: int = Query(default=10, ge=0, le=1000), session: AsyncSession = Depends(get_session)
) -> dict:
    query = select(Product).where(Product.is_active.is_(True), Product.stock < threshold).order_by(Product.stock, Product.id)
    low = (await session.execute(query)).scalars()
    return {"threshold": threshold, "products": [{"id": p.id, "sku": p.sku, "stock": p.stock} for p in low]}
