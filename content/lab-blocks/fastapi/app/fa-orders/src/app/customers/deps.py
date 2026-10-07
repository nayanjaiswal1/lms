"""Authentication dependencies: opaque API tokens sent as ``Authorization: Bearer <token>``."""

from fastapi import Depends, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.models import Customer
from app.db import get_session

UNAUTHORIZED = {"WWW-Authenticate": "Bearer"}


async def current_customer(
    authorization: str | None = Header(default=None),
    session: AsyncSession = Depends(get_session),
) -> Customer:
    scheme, _, token = (authorization or "").partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="missing bearer token", headers=UNAUTHORIZED)
    customer = (await session.execute(select(Customer).where(Customer.api_token == token))).scalar_one_or_none()
    if customer is None:
        raise HTTPException(status_code=401, detail="invalid token", headers=UNAUTHORIZED)
    return customer


async def staff_only(customer: Customer = Depends(current_customer)) -> Customer:
    if not customer.is_staff:
        raise HTTPException(status_code=403, detail="staff only")
    return customer
