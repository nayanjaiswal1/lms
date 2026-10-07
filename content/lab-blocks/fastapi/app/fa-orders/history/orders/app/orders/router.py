from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.db import get_session
from app.orders import service
from app.orders.schemas import OrderIn, OrderOut

router = APIRouter(prefix="/api/v1/orders", tags=["orders"])


@router.post("", response_model=OrderOut, status_code=201)
async def place_order(
    payload: OrderIn,
    customer: Customer = Depends(current_customer),
    session: AsyncSession = Depends(get_session),
) -> OrderOut:
    try:
        order = await service.create_order(session, customer.id, payload)
    except service.UnknownProduct:
        raise HTTPException(status_code=422, detail="unknown product") from None
    except service.OutOfStock:
        raise HTTPException(status_code=409, detail="not enough stock") from None
    return OrderOut.from_order(order)


@router.get("", response_model=list[OrderOut])
async def my_orders(
    limit: int = Query(default=100, ge=1, le=200),
    customer: Customer = Depends(current_customer),
    session: AsyncSession = Depends(get_session),
) -> list[OrderOut]:
    orders = await service.list_orders(session, customer.id, limit)
    return [OrderOut.from_order(order) for order in orders]


@router.get("/{order_id:int}", response_model=OrderOut)
async def get_order(
    order_id: int,
    customer: Customer = Depends(current_customer),
    session: AsyncSession = Depends(get_session),
) -> OrderOut:
    order = await service.get_order(session, customer.id, order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="order not found")
    return OrderOut.from_order(order)
