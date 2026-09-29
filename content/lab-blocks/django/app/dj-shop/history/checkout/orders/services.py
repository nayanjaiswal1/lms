import functools
import logging

from django.db import transaction
from django.utils import timezone

from core.clock import now
from inventory import services as inventory
from notifications.tasks import send_order_confirmation
from orders import pricing
from orders.models import Invoice, Order, OrderItem
from payments import services as payments

logger = logging.getLogger(__name__)


class EmptyOrder(Exception):
    pass


class InvalidTransition(Exception):
    pass


# mf:slot orders.services.place_order.atomic
@transaction.atomic
# mf:endslot
def place_order(customer, lines, shipping_name=""):
    """Create a paid order from (product, quantity) pairs.

    Stock is reserved, the customer is charged and the invoice issued in one
    transaction: any failure leaves no trace behind.
    """
    lines = sorted(((p, q) for p, q in lines if q > 0), key=lambda pair: pair[0].pk)
    if not lines:
        raise EmptyOrder("An order needs at least one line")
    order = Order.objects.create(customer=customer, shipping_name=shipping_name)
    priced = []
    for product, quantity in lines:
        inventory.reserve(product.pk, quantity)
        priced.append((product, quantity, product.price, pricing.line_total(product.price, quantity)))
    OrderItem.objects.bulk_create(
        [
            OrderItem(order=order, product=p, quantity=q, unit_price=price, line_total=total)
            for p, q, price, total in priced
        ]
    )
    order.subtotal, order.tax, order.total = pricing.order_totals([(price, q) for _, q, price, _ in priced])
    order.save(update_fields=["subtotal", "tax", "total"])
    payments.charge_order(order)
    order.status = Order.Status.PAID
    order.save(update_fields=["status", "updated_at"])
    Invoice.objects.create(order=order, number=f"INV-{now():%Y}-{order.pk:08d}", total=order.total)
    # mf:slot orders.services.notify_enqueue
    transaction.on_commit(functools.partial(send_order_confirmation.delay, order.pk))
    # mf:endslot
    return order


def cancel_order(order):
    if order.status not in (Order.Status.PENDING, Order.Status.PAID):
        raise InvalidTransition(f"Cannot cancel an order that is {order.status}")
    with transaction.atomic():
        for item in order.items.all():
            inventory.release(item.product_id, item.quantity)
        order.status = Order.Status.CANCELLED
        order.save(update_fields=["status", "updated_at"])
    return order


def _log_shipped(order_id):
    logger.info("order %s marked as shipped", order_id)


def bulk_ship(order_ids):
    """Mark paid orders as shipped; returns how many changed."""
    with transaction.atomic():
        orders = list(Order.objects.select_for_update().filter(pk__in=order_ids, status=Order.Status.PAID))
        for order in orders:
            order.status = Order.Status.SHIPPED
            order.updated_at = timezone.now()
            order.save(update_fields=["status", "updated_at"])
            # mf:slot orders.services.shipped_callbacks
            transaction.on_commit(functools.partial(_log_shipped, order.pk))
            # mf:endslot
    return len(orders)
