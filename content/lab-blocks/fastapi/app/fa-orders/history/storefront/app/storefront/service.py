import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.catalog.models import Product
from app.catalog.schemas import ProductOut
from app.storefront.downstream import Downstream


async def build_storefront(session: AsyncSession, downstream: Downstream) -> dict:
    """The storefront home page: featured products, current promotions and the shipping notice."""
    query = select(Product).where(Product.is_active.is_(True), Product.stock > 0).order_by(Product.id).limit(3)
    featured = list((await session.execute(query)).scalars())
    # The two remote lookups do not depend on each other.
    # mf:slot storefront.service.compose
    promotions, shipping = await asyncio.gather(downstream.promotions(), downstream.shipping_notice())
    # mf:endslot
    return {
        "featured": [ProductOut.model_validate(p).model_dump() for p in featured],
        "promotions": promotions,
        "shipping_notice": shipping,
    }
