from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.db import get_session
from app.payments import service
from app.payments.client import PaymentDeclined, PaymentError, PaymentsClient, PaymentTimeout, PaymentUnavailable

router = APIRouter(prefix="/api/v1/orders", tags=["payments"])


class PaymentOut(BaseModel):
    order_id: int
    status: str
    charge_id: str
    amount_cents: int


def payments_client(request: Request) -> PaymentsClient:
    return request.app.state.payments


@router.post("/{order_id:int}/pay", response_model=PaymentOut)
async def pay(
    order_id: int,
    customer: Customer = Depends(current_customer),
    session: AsyncSession = Depends(get_session),
    client: PaymentsClient = Depends(payments_client),
) -> PaymentOut:
    try:
        payment = await service.pay_order(session, client, customer.id, order_id)
    except service.OrderNotFound:
        raise HTTPException(status_code=404, detail="order not found") from None
    except service.OrderNotPayable:
        raise HTTPException(status_code=409, detail="order cannot be paid") from None
    except PaymentDeclined:
        raise HTTPException(status_code=402, detail="card declined") from None
    except PaymentTimeout:
        raise HTTPException(status_code=504, detail="payments provider timed out") from None
    except (PaymentUnavailable, PaymentError):
        raise HTTPException(status_code=502, detail="payments provider unavailable") from None
    return PaymentOut(
        order_id=payment.order_id,
        status=payment.status,
        charge_id=payment.provider_charge_id,
        amount_cents=payment.amount_cents,
    )
