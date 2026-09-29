from django.core import mail

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def _order():
    from orders.models import Order

    return Order.objects.create(customer=make_customer("buyer@shop.test"), total=10, subtotal=10)


def test_confirmation_email_is_sent_once_even_if_task_runs_twice():
    from notifications.models import EmailLog
    from notifications.tasks import send_order_confirmation

    order = _order()
    assert send_order_confirmation.delay(order.pk).get() is True
    assert send_order_confirmation.delay(order.pk).get() is False
    assert len(mail.outbox) == 1
    assert mail.outbox[0].to == ["buyer@shop.test"]
    assert EmailLog.objects.filter(kind="order-confirmation", reference=str(order.pk)).count() == 1


def test_different_kinds_are_independent():
    from notifications.tasks import send_order_confirmation, send_order_shipped

    order = _order()
    send_order_confirmation.delay(order.pk)
    send_order_shipped.delay(order.pk)
    assert len(mail.outbox) == 2


def test_low_stock_digest_lists_only_low_products():
    from notifications.tasks import send_low_stock_alert

    low, plenty = make_product(sku="LOW-1"), make_product(sku="OK-1")
    make_stock(low, 1)
    make_stock(plenty, 500)
    assert send_low_stock_alert() == 1
    assert "LOW-1" in mail.outbox[-1].body and "OK-1" not in mail.outbox[-1].body
