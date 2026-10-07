from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.catalog.models import Product
from app.catalog.schemas import ProductOut
from app.db import get_session

router = APIRouter(prefix="/api/v1/products", tags=["catalog"])


@router.get("", response_model=list[ProductOut])
async def list_products(
    category: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> list[Product]:
    query = select(Product).where(Product.is_active.is_(True)).order_by(Product.id).limit(limit).offset(offset)
    if category:
        query = query.where(Product.category == category)
    return list((await session.execute(query)).scalars())


@router.get("/{product_id:int}", response_model=ProductOut)
async def get_product(product_id: int, session: AsyncSession = Depends(get_session)) -> Product:
    product = await session.get(Product, product_id)
    if product is None or not product.is_active:
        raise HTTPException(status_code=404, detail="product not found")
    return product
