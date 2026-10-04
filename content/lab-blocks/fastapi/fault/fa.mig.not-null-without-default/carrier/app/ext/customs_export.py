"""Staff endpoint for the customs paperwork: every live product with its harmonized system (HS) code."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.catalog.models import Product
from app.customers.deps import staff_only
from app.db import get_session

router = APIRouter(prefix="/api/v1/staff", tags=["customs"], dependencies=[Depends(staff_only)])


@router.get("/customs-export")
async def customs_export(session: AsyncSession = Depends(get_session)) -> dict:
    products = (await session.execute(select(Product).where(Product.is_active.is_(True)).order_by(Product.id))).scalars()
    return {"products": [{"sku": p.sku, "name": p.name, "hs_code": p.hs_code} for p in products]}
