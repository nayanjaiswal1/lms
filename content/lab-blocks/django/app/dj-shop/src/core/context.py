"""Per-request context (current customer) available to signals and services."""

from contextvars import ContextVar

# mf:slot core.context.storage
_current_customer = ContextVar("current_customer", default=None)


def set_current_customer(customer):
    return _current_customer.set(customer)


def get_current_customer():
    return _current_customer.get()


def reset_current_customer(token):
    _current_customer.reset(token)


# mf:endslot
