from django.db import IntegrityError, transaction

from core.audit import record_audit
from customers.models import Customer


class EmailTaken(Exception):
    pass


def register(email, password, full_name=""):
    """Create a customer; the unique constraint on email is the arbiter."""
    # mf:slot customers.services.register
    try:
        with transaction.atomic():
            customer = Customer.objects.create_user(email, password, full_name=full_name)
    except IntegrityError as exc:
        raise EmailTaken(email) from exc
    # mf:endslot
    return customer


def close_account(customer):
    """Deactivate and anonymise a customer while keeping their order history."""
    with transaction.atomic():
        record_audit("customer.closed", customer)
        customer.is_active = False
        customer.full_name = ""
        customer.phone = None
        customer.email = f"closed-{customer.pk}@deleted.invalid"
        customer.set_unusable_password()
        customer.save()
