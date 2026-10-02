"""Customers with order history cannot be deleted, so their orders and invoices survive."""

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_customers_with_orders_cannot_be_deleted():
    from django.db.models import ProtectedError

    from orders.models import Invoice, Order

    user = make_customer()
    order = Order.objects.create(customer=user, status="paid", subtotal=5, total=5)
    Invoice.objects.create(order=order, number="INV-T-1", total=5)
    with pytest.raises(ProtectedError):
        user.delete()
    assert Invoice.objects.count() == 1 and Order.objects.count() == 1
