from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver

from core.audit import record_audit
from notifications.tasks import send_order_shipped
from orders.models import Order


# mf:slot orders.signals.order_saved
@receiver(post_save, sender=Order)
def order_saved(sender, instance, created, **kwargs):
    """Keep the audit trail and tell customers when their order ships."""
    if created:
        record_audit("order.created", instance)
    elif instance.status_changed:
        record_audit("order.status_changed", instance, status=instance.status)
        if instance.status == Order.Status.SHIPPED:
            order_id = instance.pk
            transaction.on_commit(lambda: send_order_shipped.delay(order_id))


# mf:endslot
