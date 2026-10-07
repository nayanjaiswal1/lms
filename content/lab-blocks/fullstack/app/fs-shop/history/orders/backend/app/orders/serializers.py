"""The JSON shape of an order, shared by every endpoint that returns one."""


def serialize_order(order: dict) -> dict:
    return {
        "id": order["id"],
        "status": order["status"],
        # mf:slot orders.serialize.total
        "total_cents": order["total_cents"],
        # mf:endslot
        # mf:slot orders.serialize.placed_at
        "placed_at": order["placed_at"].isoformat(),
        # mf:endslot
        "item_count": sum(item["quantity"] for item in order["items"]),
    }
