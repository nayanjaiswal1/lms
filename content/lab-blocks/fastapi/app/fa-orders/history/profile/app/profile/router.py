from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.deps import current_customer
from app.customers.models import Customer
from app.customers.schemas import CustomerOut
from app.db import get_session
from app.profile import service
from app.profile.schemas import ProfileUpdate

router = APIRouter(prefix="/api/v1", tags=["profile"])


@router.patch("/me", response_model=CustomerOut)
async def update_me(
    payload: ProfileUpdate,
    customer: Customer = Depends(current_customer),
    session: AsyncSession = Depends(get_session),
) -> Customer:
    return await service.update_profile(session, customer, payload)
