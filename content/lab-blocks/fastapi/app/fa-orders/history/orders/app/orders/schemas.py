from datetime import datetime

from pydantic import BaseModel, Field

from app.orders.models import Order


class OrderLineIn(BaseModel):
    product_id: int
    quantity: int = Field(ge=1, le=100)


class OrderIn(BaseModel):
    items: list[OrderLineIn] = Field(min_length=1, max_length=50)
    shipping_name: str | None = Field(default=None, max_length=120)


class OrderItemOut(BaseModel):
    product_id: int
    product_name: str
    quantity: int
    unit_price_cents: int


class OrderOut(BaseModel):
    id: int
    status: str
    total_cents: int
    currency: str
    shipping_name: str | None
    created_at: datetime
    items: list[OrderItemOut]

    @classmethod
    def from_order(cls, order: Order) -> "OrderOut":
        return cls(
            id=order.id,
            status=order.status,
            total_cents=order.total_cents,
            currency=order.currency,
            shipping_name=order.shipping_name,
            created_at=order.created_at,
            items=[
                OrderItemOut(
                    product_id=item.product_id,
                    product_name=item.product.name,
                    quantity=item.quantity,
                    unit_price_cents=item.unit_price_cents,
                )
                for item in order.items
            ],
        )
