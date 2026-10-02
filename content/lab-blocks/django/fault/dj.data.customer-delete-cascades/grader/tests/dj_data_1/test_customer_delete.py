from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_deleting_a_customer_never_removes_their_orders_or_invoices():
    from django.db.models import ProtectedError

    from customers.models import Customer
    from orders.models import Invoice, Order

    user = make_customer()
    order = Order.objects.create(customer=user, status="paid", subtotal=5, total=5)
    Invoice.objects.create(order=order, number="INV-HIDDEN-1", total=5)
    try:
        user.delete()
    except ProtectedError:
        pass
    assert Invoice.objects.filter(number="INV-HIDDEN-1").exists()
    assert Order.objects.filter(pk=order.pk).exists()
    assert Customer.objects.filter(pk=user.pk).exists(), "the customer must not disappear while orders reference them"
