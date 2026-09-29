from core.money import to_cents
from payments.client import PaymentDeclined, PaymentsClient
from payments.models import Payment


def charge_order(order, client=None):
    """Charge the order total. Raises a PaymentError subclass on failure."""
    client = client or PaymentsClient()
    payment = Payment.objects.create(
        order=order, amount=order.total, idempotency_key=order.public_id, status=Payment.Status.PENDING
    )
    result = client.charge(
        amount_cents=to_cents(order.total),
        currency=order.currency,
        reference=f"order-{order.pk}",
        idempotency_key=order.public_id,
    )
    payment.provider_ref = result.id
    if result.status != "succeeded":
        payment.status = Payment.Status.FAILED
        payment.save(update_fields=["status", "provider_ref"])
        raise PaymentDeclined(result.status)
    payment.status = Payment.Status.SUCCEEDED
    payment.save(update_fields=["status", "provider_ref"])
    return payment
