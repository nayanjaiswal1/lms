from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.orders.models import Order
from app.payments.client import PaymentsClient
from app.payments.models import Payment


class OrderNotFound(Exception):
    pass


class OrderNotPayable(Exception):
    pass


async def pay_order(session: AsyncSession, client: PaymentsClient, customer_id: int, order_id: int) -> Payment:
    """Charge an order once. Paying an already paid order returns the existing payment."""
    # The row lock serialises concurrent attempts to pay the same order.
    order = (
        await session.execute(
            select(Order).where(Order.id == order_id, Order.customer_id == customer_id).with_for_update()
        )
    ).scalar_one_or_none()
    if order is None:
        raise OrderNotFound()
    if order.status == "paid":
        return (await session.execute(select(Payment).where(Payment.order_id == order.id))).scalar_one()
    if order.status != "pending":
        raise OrderNotPayable()

    charge = await client.charge(
        amount_cents=order.total_cents,
        currency=order.currency,
        reference=f"order-{order.id}",
        idempotency_key=f"order-{order.id}",
    )
    payment = Payment(order_id=order.id, provider_charge_id=charge.id, status=charge.status, amount_cents=charge.amount_cents)
    session.add(payment)
    order.status = "paid"
    await session.commit()
    return payment
