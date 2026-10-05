from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field

from ..auth import csrf_protect, current_user
from ..deps import get_store
from ..orders.serializers import serialize_order
from ..store import Store
from .service import place_order

router = APIRouter(prefix="/orders", tags=["checkout"])


class OrderLine(BaseModel):
    product_id: int
    quantity: int = Field(ge=1)


class NewOrder(BaseModel):
    items: list[OrderLine] = Field(min_length=1, max_length=20)


@router.post("", status_code=201, dependencies=[Depends(csrf_protect)])
def create_order(body: NewOrder, response: Response, user: dict = Depends(current_user), store: Store = Depends(get_store)) -> dict:
    order = place_order(store, user["id"], [(line.product_id, line.quantity) for line in body.items])
    response.headers["Location"] = f"/api/orders/{order['id']}"
    return serialize_order(order)
