"""Finance export: the signed-in customer's orders as CSV."""

import csv
import io

from fastapi import APIRouter, Depends
from fastapi.responses import PlainTextResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.db import get_session
from app.orders import service

router = APIRouter(prefix="/api/v1/exports", tags=["exports"])


@router.get("/orders", response_class=PlainTextResponse)
async def export_orders(
    customer: Customer = Depends(current_customer), session: AsyncSession = Depends(get_session)
) -> PlainTextResponse:
    orders = await service.list_orders(session, customer.id, 200)
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["order_id", "status", "items", "total_cents", "created_at"])
    for order in orders:
        writer.writerow([order.id, order.status, sum(i.quantity for i in order.items), order.total_cents, order.created_at.isoformat()])
    return PlainTextResponse(out.getvalue(), media_type="text/csv")
