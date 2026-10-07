from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.catalog.models import Product
from app.catalog.schemas import ProductOut
from app.db import get_session

router = APIRouter(prefix="/api/v1/products", tags=["search"])


def _like_pattern(term: str) -> str:
    escaped = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


@router.get("/search", response_model=list[ProductOut])
async def search_products(
    q: str = Query(min_length=2, max_length=60),
    limit: int = Query(default=20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> list[Product]:
    pattern = _like_pattern(q)
    query = (
        select(Product)
        .where(Product.is_active.is_(True), Product.name.ilike(pattern, escape="\\") | Product.sku.ilike(pattern, escape="\\"))
        .order_by(Product.name)
        .limit(limit)
    )
    return list((await session.execute(query)).scalars())
