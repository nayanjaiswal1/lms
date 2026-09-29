from django.db import IntegrityError, transaction

from core.audit import record_audit
from core.clock import now
from subscriptions.models import Subscription


def subscribe(customer, plan):
    """Return (subscription, created). The partial unique index is the arbiter."""
    # mf:slot subscriptions.service.subscribe
    try:
        with transaction.atomic():
            return Subscription.objects.create(customer=customer, plan=plan), True
    except IntegrityError:
        return Subscription.objects.get(customer=customer, plan=plan, status=Subscription.Status.ACTIVE), False
    # mf:endslot


def cancel(subscription):
    if subscription.status != Subscription.Status.ACTIVE:
        return subscription
    subscription.status = Subscription.Status.CANCELED
    subscription.canceled_at = now()
    subscription.save(update_fields=["status", "canceled_at"])
    record_audit("subscription.canceled", subscription)
    return subscription
