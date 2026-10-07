from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.catalog.models import Product
from app.catalog.schemas import ProductOut
from app.db import get_session
from app.search.synonyms import lookup_synonyms

router = APIRouter(prefix="/api/v1/products", tags=["search"])


def _like_pattern(term: str) -> str:
    escaped = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{escaped}%"


@router.get("/search", response_model=list[ProductOut])
async def search_products(
    request: Request,
    q: str = Query(min_length=2, max_length=60),
    limit: int = Query(default=20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> list[Product]:
    latency = request.app.state.settings.synonym_latency_seconds
    # mf:slot search.router.synonyms
    synonyms = await run_in_threadpool(lookup_synonyms, q, latency)
    # mf:endslot
    patterns = [_like_pattern(term) for term in (q, *synonyms)]
    matches = [Product.name.ilike(p, escape="\\") | Product.sku.ilike(p, escape="\\") for p in patterns]
    query = select(Product).where(Product.is_active.is_(True), or_(*matches)).order_by(Product.name).limit(limit)
    return list((await session.execute(query)).scalars())
