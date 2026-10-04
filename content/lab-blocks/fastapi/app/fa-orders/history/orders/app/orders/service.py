from collections import Counter

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.catalog.models import Product
from app.orders.models import Order, OrderItem
from app.orders.schemas import OrderIn


class UnknownProduct(Exception):
    pass


class OutOfStock(Exception):
    pass


async def create_order(session: AsyncSession, customer_id: int, payload: OrderIn) -> Order:
    wanted = Counter()
    for line in payload.items:
        wanted[line.product_id] += line.quantity
    rows = await session.execute(select(Product).where(Product.id.in_(wanted), Product.is_active.is_(True)))
    products = {product.id: product for product in rows.scalars()}
    if set(wanted) - products.keys():
        raise UnknownProduct()
    for product_id, quantity in wanted.items():
        if products[product_id].stock < quantity:
            raise OutOfStock()

    for product_id, quantity in wanted.items():
        reserved = await session.execute(
            update(Product).where(Product.id == product_id, Product.stock >= quantity).values(stock=Product.stock - quantity)
        )
        if reserved.rowcount != 1:
            await session.rollback()
            raise OutOfStock()

    order = Order(
        customer_id=customer_id,
        total_cents=sum(products[pid].price_cents * qty for pid, qty in wanted.items()),
        shipping_name=payload.shipping_name,
        items=[
            OrderItem(product=products[pid], product_id=pid, quantity=qty, unit_price_cents=products[pid].price_cents)
            for pid, qty in wanted.items()
        ],
    )
    session.add(order)
    await session.commit()
    return order


async def list_orders(session: AsyncSession, customer_id: int, limit: int) -> list[Order]:
    # mf:slot orders.service.list_for_customer
    query = (
        select(Order)
        .where(Order.customer_id == customer_id)
        .options(selectinload(Order.items).joinedload(OrderItem.product))
        .order_by(Order.id.desc())
        .limit(limit)
    )
    orders = list((await session.execute(query)).scalars())
    # mf:endslot
    return orders


async def get_order(session: AsyncSession, customer_id: int, order_id: int) -> Order | None:
    # mf:slot orders.service.get_one
    query = (
        select(Order)
        .where(Order.id == order_id, Order.customer_id == customer_id)
        .options(selectinload(Order.items).joinedload(OrderItem.product))
    )
    # mf:endslot
    return (await session.execute(query)).scalar_one_or_none()
