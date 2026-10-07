from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.db import get_session
from app.wallet import service
from app.wallet.schemas import CreditIn, TransactionOut, WalletOut

router = APIRouter(prefix="/api/v1/wallet", tags=["wallet"])


@router.get("", response_model=WalletOut)
async def balance(customer: Customer = Depends(current_customer)) -> WalletOut:
    return WalletOut(balance_cents=customer.credit_cents)


@router.get("/transactions", response_model=list[TransactionOut])
async def transactions(
    customer: Customer = Depends(current_customer), session: AsyncSession = Depends(get_session)
) -> list[TransactionOut]:
    return await service.recent_transactions(session, customer.id)


@router.post("/credit", response_model=WalletOut)
async def add_credit(
    payload: CreditIn,
    customer: Customer = Depends(current_customer),
    session: AsyncSession = Depends(get_session),
) -> WalletOut:
    balance_cents = await service.apply_credit(session, customer.id, payload.amount_cents, payload.reason)
    return WalletOut(balance_cents=balance_cents)
