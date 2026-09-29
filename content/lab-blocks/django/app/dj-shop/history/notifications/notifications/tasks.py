import logging

from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail
from django.db import IntegrityError, transaction

from notifications.models import EmailLog

logger = logging.getLogger(__name__)


def _send_once(kind, reference, recipient, subject, body):
    """Send an email at most once per (kind, reference), even if the task is retried."""
    # mf:slot notifications.tasks.send_once
    try:
        with transaction.atomic():
            EmailLog.objects.create(kind=kind, reference=reference, recipient=recipient)
    except IntegrityError:
        logger.info("email %s:%s already sent, skipping", kind, reference)
        return False
    # mf:endslot
    send_mail(subject, body, settings.DEFAULT_FROM_EMAIL, [recipient])
    return True


@shared_task(bind=True, autoretry_for=(ConnectionError,), retry_backoff=True, max_retries=3)
def send_order_confirmation(self, order_id):
    from orders.models import Order

    order = Order.objects.select_related("customer").get(pk=order_id)
    return _send_once(
        "order-confirmation",
        str(order.pk),
        order.customer.email,
        f"Order #{order.pk} confirmed",
        f"Thanks for your order! Total: {order.total} {order.currency}.",
    )


@shared_task(bind=True, autoretry_for=(ConnectionError,), retry_backoff=True, max_retries=3)
def send_order_shipped(self, order_id):
    from orders.models import Order

    order = Order.objects.select_related("customer").get(pk=order_id)
    return _send_once(
        "order-shipped",
        str(order.pk),
        order.customer.email,
        f"Order #{order.pk} has shipped",
        "Your order is on its way.",
    )


@shared_task
def send_low_stock_alert():
    """Email the ops mailbox a digest of products under the low-stock threshold."""
    from django.db.models import Sum

    from catalog.models import Product

    low = (
        Product.objects.annotate(stock=Sum("stock_levels__on_hand"))
        .filter(stock__lt=settings.LOW_STOCK_THRESHOLD)
        .order_by("stock", "sku")
    )
    lines = [f"{p.sku}: {p.stock or 0} left" for p in low[:50]]
    if not lines:
        return 0
    send_mail("Low stock digest", "\n".join(lines), settings.DEFAULT_FROM_EMAIL, ["ops@shop.example.com"])
    return len(lines)
