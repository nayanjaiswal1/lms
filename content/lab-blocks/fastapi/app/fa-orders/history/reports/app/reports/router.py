from datetime import date

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import Date, cast, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import staff_only
from app.db import get_session
from app.orders.models import Order

router = APIRouter(prefix="/api/v1/staff/reports", tags=["reports"], dependencies=[Depends(staff_only)])


class SalesDay(BaseModel):
    day: date
    orders: int
    revenue_cents: int


@router.get("/sales", response_model=list[SalesDay])
async def sales_by_day(
    days: int = Query(default=7, ge=1, le=366), session: AsyncSession = Depends(get_session)
) -> list[SalesDay]:
    """Paid orders per UTC day over the last ``days`` days."""
    day = cast(func.timezone("UTC", Order.created_at), Date)
    query = (
        select(day.label("day"), func.count(Order.id), func.coalesce(func.sum(Order.total_cents), 0))
        .where(Order.status == "paid", Order.created_at >= func.now() - func.make_interval(0, 0, 0, days))
        .group_by(day)
        .order_by(day)
    )
    rows = (await session.execute(query)).all()
    return [SalesDay(day=row[0], orders=row[1], revenue_cents=row[2]) for row in rows]
