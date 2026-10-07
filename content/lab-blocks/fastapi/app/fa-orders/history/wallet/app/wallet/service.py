from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.customers.models import Customer
from app.wallet.models import WalletTransaction


async def apply_credit(session: AsyncSession, customer_id: int, amount_cents: int, reason: str) -> int:
    """Add store credit and record it in the ledger. Returns the new balance."""
    # mf:slot wallet.service.apply_credit
    result = await session.execute(
        update(Customer)
        .where(Customer.id == customer_id)
        .values(credit_cents=Customer.credit_cents + amount_cents)
        .returning(Customer.credit_cents)
    )
    balance = result.scalar_one()
    # mf:endslot
    session.add(
        WalletTransaction(customer_id=customer_id, delta_cents=amount_cents, reason=reason, balance_after_cents=balance)
    )
    await session.commit()
    return balance


async def recent_transactions(session: AsyncSession, customer_id: int, limit: int = 20) -> list[WalletTransaction]:
    query = (
        select(WalletTransaction)
        .where(WalletTransaction.customer_id == customer_id)
        .order_by(WalletTransaction.id.desc())
        .limit(limit)
    )
    return list((await session.execute(query)).scalars())
