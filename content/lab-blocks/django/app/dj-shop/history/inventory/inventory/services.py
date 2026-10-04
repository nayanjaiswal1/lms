from django.conf import settings
from django.db import transaction
from django.db.models import F, Sum

from core.audit import record_audit
from inventory.models import StockLevel, Warehouse


class OutOfStock(Exception):
    def __init__(self, product_id):
        super().__init__(f"Not enough stock for product {product_id}")
        self.product_id = product_id


def default_warehouse():
    return Warehouse.objects.get(code=settings.DEFAULT_WAREHOUSE_CODE)


def available(product_id):
    """Units on hand across every warehouse."""
    return StockLevel.objects.filter(product_id=product_id).aggregate(n=Sum("on_hand"))["n"] or 0


def reserve(product_id, quantity, warehouse=None):
    """Take ``quantity`` units out of stock or raise OutOfStock. Safe under concurrency."""
    warehouse = warehouse or default_warehouse()
    # mf:slot inventory.services.reserve
    updated = StockLevel.objects.filter(
        product_id=product_id, warehouse=warehouse, on_hand__gte=quantity
    ).update(on_hand=F("on_hand") - quantity)
    if not updated:
        raise OutOfStock(product_id)
    # mf:endslot


def release(product_id, quantity, warehouse=None):
    """Return units to stock (order cancelled or payment failed)."""
    warehouse = warehouse or default_warehouse()
    StockLevel.objects.filter(product_id=product_id, warehouse=warehouse).update(on_hand=F("on_hand") + quantity)


def transfer(product_id, source, destination, quantity):
    """Move stock between warehouses atomically."""
    if source.pk == destination.pk:
        raise ValueError("Source and destination must differ")
    with transaction.atomic():
        # mf:slot inventory.services.transfer_locks
        ids = sorted([source.pk, destination.pk])
        locked = {
            level.warehouse_id: level
            for level in StockLevel.objects.select_for_update()
            .filter(product_id=product_id, warehouse_id__in=ids)
            .order_by("warehouse_id")
        }
        # mf:endslot
        src = locked.get(source.pk)
        if src is None or src.on_hand < quantity:
            raise OutOfStock(product_id)
        dst = locked.get(destination.pk)
        if dst is None:
            dst = StockLevel(product_id=product_id, warehouse=destination, on_hand=0)
        src.on_hand -= quantity
        dst.on_hand += quantity
        src.save(update_fields=["on_hand"])
        dst.save()
        record_audit("stock.transferred", src, to=destination.code, quantity=quantity)
