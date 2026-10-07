"""Placing an order: validate every line, take the stock and record the order in one locked step."""

from datetime import datetime, timezone

from ..errors import ApiError
from ..store import Store

STATUS_NEW = "pending"
MAX_QUANTITY = 20


def place_order(store: Store, user_id: int, lines: list[tuple[int, int]]) -> dict:
    wanted: dict[int, int] = {}
    for product_id, quantity in lines:
        wanted[product_id] = wanted.get(product_id, 0) + quantity
    with store.lock:
        for product_id, quantity in wanted.items():
            product = store.products.get(product_id)
            if product is None:
                raise ApiError(404, "product_not_found", f"No product with id {product_id}.")
            if quantity > MAX_QUANTITY:
                raise ApiError(422, "quantity_too_large", f"At most {MAX_QUANTITY} of {product['name']} per order.")
            if quantity > product["stock"]:
                raise ApiError(409, "insufficient_stock", f"Only {product['stock']} left of {product['name']}.")
        return store.add_order(user_id, list(wanted.items()), STATUS_NEW, datetime.now(timezone.utc))
