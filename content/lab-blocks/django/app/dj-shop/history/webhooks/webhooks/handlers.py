import logging

from django.db import transaction

from orders.models import Order
from payments.models import Payment

logger = logging.getLogger(__name__)


def handle_event(event):
    """Apply one provider event. Handlers are idempotent: replays change nothing."""
    kind = event.get("type")
    reference = (event.get("data") or {}).get("reference", "")
    handler = HANDLERS.get(kind)
    if handler is None:
        logger.info("ignoring webhook event type %r", kind)
        return False
    return handler(reference, event["data"])


def _order_from_reference(reference):
    if not reference.startswith("order-"):
        return None
    return Order.objects.select_for_update().filter(pk=reference.removeprefix("order-")).first()


def payment_succeeded(reference, data):
    with transaction.atomic():
        order = _order_from_reference(reference)
        if order is None:
            return False
        Payment.objects.filter(order=order, status=Payment.Status.PENDING).update(
            status=Payment.Status.SUCCEEDED, provider_ref=data.get("id", "")
        )
        if order.status == Order.Status.PENDING:
            order.status = Order.Status.PAID
            order.save(update_fields=["status", "updated_at"])
    return True


def payment_refunded(reference, data):
    with transaction.atomic():
        order = _order_from_reference(reference)
        if order is None:
            return False
        Payment.objects.filter(order=order, status=Payment.Status.SUCCEEDED).update(status=Payment.Status.REFUNDED)
        if order.status != Order.Status.REFUNDED:
            order.status = Order.Status.REFUNDED
            order.save(update_fields=["status", "updated_at"])
    return True


HANDLERS = {"payment.succeeded": payment_succeeded, "payment.refunded": payment_refunded}
