"""Public product feed for partner sites."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.catalog.models import Product
from app.db import get_session

router = APIRouter(tags=["feeds"])


@router.get("/feeds/products.json")
async def product_feed(session: AsyncSession = Depends(get_session)) -> dict:
    products = (await session.execute(select(Product).where(Product.is_active.is_(True)).order_by(Product.id))).scalars()
    return {
        "products": [
            {"sku": p.sku, "name": p.name, "price_cents": p.price_cents, "in_stock": p.stock > 0} for p in products
        ]
    }
