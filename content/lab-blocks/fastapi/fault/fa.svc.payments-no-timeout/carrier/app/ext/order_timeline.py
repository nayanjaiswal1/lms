"""The history of one order: placed, paid, refunded."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.db import get_session
from app.orders.models import Order
from app.payments.models import Payment

router = APIRouter(prefix="/api/v1/orders", tags=["timeline"])


@router.get("/{order_id:int}/timeline")
async def order_timeline(
    order_id: int, customer: Customer = Depends(current_customer), session: AsyncSession = Depends(get_session)
) -> dict:
    order = (
        await session.execute(select(Order).where(Order.id == order_id, Order.customer_id == customer.id))
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=404, detail="order not found")
    events = [{"event": "placed", "at": order.created_at.isoformat()}]
    payment = (await session.execute(select(Payment).where(Payment.order_id == order.id))).scalar_one_or_none()
    if payment is not None:
        events.append({"event": "paid", "at": payment.created_at.isoformat()})
    if order.status == "refunded":
        events.append({"event": "refunded", "at": order.updated_at.isoformat()})
    return {"order_id": order.id, "status": order.status, "events": events}
