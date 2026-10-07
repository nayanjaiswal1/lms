"""A one-call summary of the signed-in customer's account."""

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.db import get_session
from app.orders.models import Order

router = APIRouter(prefix="/api/v1/me", tags=["account"])


@router.get("/overview")
async def account_overview(
    customer: Customer = Depends(current_customer), session: AsyncSession = Depends(get_session)
) -> dict:
    count, last = (
        await session.execute(select(func.count(Order.id), func.max(Order.created_at)).where(Order.customer_id == customer.id))
    ).one()
    return {
        "orders": count,
        "last_order_at": last.isoformat() if last else None,
        "wallet_balance_cents": customer.credit_cents,
    }
