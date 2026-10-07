from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.customers.schemas import CustomerOut, LoginIn, LoginOut
from app.customers.security import verify_password
from app.db import get_session

router = APIRouter(prefix="/api/v1", tags=["customers"])


@router.post("/auth/login", response_model=LoginOut)
async def login(payload: LoginIn, session: AsyncSession = Depends(get_session)) -> LoginOut:
    customer = (await session.execute(select(Customer).where(Customer.email == payload.email.lower()))).scalar_one_or_none()
    if customer is None or not await verify_password(payload.password, customer.password_hash):
        raise HTTPException(status_code=401, detail="invalid email or password")
    return LoginOut(token=customer.api_token, customer=CustomerOut.model_validate(customer))


@router.get("/me", response_model=CustomerOut)
async def me(customer: Customer = Depends(current_customer)) -> Customer:
    return customer
