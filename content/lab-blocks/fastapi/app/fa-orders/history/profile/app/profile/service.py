from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.models import Customer
from app.profile.schemas import ProfileUpdate


async def update_profile(session: AsyncSession, customer: Customer, payload: ProfileUpdate) -> Customer:
    # mf:slot profile.service.changes
    changes = payload.model_dump(exclude_unset=True)
    # mf:endslot
    for field, value in changes.items():
        setattr(customer, field, value)
    await session.commit()
    return customer
