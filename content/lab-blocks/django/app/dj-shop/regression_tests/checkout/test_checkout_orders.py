from decimal import Decimal

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def _place(user, lines, **kw):
    from orders import services

    return services.place_order(user, lines, **kw)


def test_place_order_totals_stock_invoice_and_payment(fake_payments, django_capture_on_commit_callbacks):
    from django.core import mail

    from inventory.models import StockLevel
    from orders.models import Invoice

    user = make_customer()
    a, b = make_product("19.99"), make_product("5.05")
    make_stock(a, 10)
    make_stock(b, 10)
    with django_capture_on_commit_callbacks(execute=True):
        order = _place(user, [(a, 3), (b, 2)])
    assert order.status == "paid"
    assert order.subtotal == Decimal("70.07")
    assert order.tax == Decimal("5.78")
    assert order.total == Decimal("75.85")
    assert [i.line_total for i in order.items.order_by("product_id")] == [Decimal("59.97"), Decimal("10.10")]
    assert StockLevel.objects.get(product=a).on_hand == 7
    assert Invoice.objects.get(order=order).total == order.total
    assert fake_payments.charges[0]["amount_cents"] == 7585
    assert fake_payments.charges[0]["key"] == str(order.public_id)
    assert len(mail.outbox) == 1


def test_totals_are_exact_for_awkward_prices(fake_payments):
    user = make_customer()
    product = make_product("0.10")
    make_stock(product, 100)
    order = _place(user, [(product, 3)])
    assert order.subtotal == Decimal("0.30")
    assert order.total == order.subtotal + order.tax


def test_failed_payment_leaves_nothing_behind(fake_payments):
    from inventory.models import StockLevel
    from orders.models import Order
    from payments.client import PaymentDeclined
    from payments.models import Payment

    user = make_customer()
    product = make_product()
    make_stock(product, 4)
    fake_payments.status = "declined"
    with pytest.raises(PaymentDeclined):
        _place(user, [(product, 2)])
    assert Order.objects.count() == 0 and Payment.objects.count() == 0
    assert StockLevel.objects.get(product=product).on_hand == 4


def test_out_of_stock_rolls_back_whole_order(fake_payments):
    from inventory import services as inventory
    from orders.models import Order

    user = make_customer()
    a, b = make_product(), make_product()
    make_stock(a, 5)
    make_stock(b, 1)
    with pytest.raises(inventory.OutOfStock):
        _place(user, [(a, 2), (b, 2)])
    assert Order.objects.count() == 0
    assert inventory.available(a.pk) == 5


def test_confirmation_is_only_enqueued_after_commit(fake_payments, django_capture_on_commit_callbacks, monkeypatch):
    seen = []
    monkeypatch.setattr("orders.services.send_order_confirmation.delay", lambda pk: seen.append(pk))
    user = make_customer()
    product = make_product()
    make_stock(product, 3)
    with django_capture_on_commit_callbacks(execute=False) as callbacks:
        order = _place(user, [(product, 1)])
    assert seen == [] and len(callbacks) >= 1
    for callback in callbacks:
        callback()
    assert seen == [order.pk]


def test_empty_order_is_rejected(fake_payments):
    from orders import services

    with pytest.raises(services.EmptyOrder):
        _place(make_customer(), [])


def test_cancel_releases_stock_and_rejects_shipped(fake_payments):
    from inventory import services as inventory
    from orders import services

    user = make_customer()
    product = make_product()
    make_stock(product, 5)
    order = _place(user, [(product, 2)])
    services.cancel_order(order)
    assert order.status == "cancelled" and inventory.available(product.pk) == 5
    shipped = _place(user, [(product, 1)])
    shipped.status = "shipped"
    shipped.save()
    with pytest.raises(services.InvalidTransition):
        services.cancel_order(shipped)


def test_bulk_ship_only_ships_paid_orders_and_logs_each(fake_payments, django_capture_on_commit_callbacks, caplog):
    import logging

    from orders import services

    user = make_customer()
    product = make_product()
    make_stock(product, 20)
    paid = [_place(user, [(product, 1)]) for _ in range(3)]
    cancelled = _place(user, [(product, 1)])
    services.cancel_order(cancelled)
    caplog.set_level(logging.INFO, logger="orders.services")
    with django_capture_on_commit_callbacks(execute=True):
        count = services.bulk_ship([o.pk for o in paid] + [cancelled.pk])
    assert count == 3
    logged = sorted(r.getMessage() for r in caplog.records if "marked as shipped" in r.getMessage())
    assert logged == sorted(f"order {o.pk} marked as shipped" for o in paid)


def test_status_change_writes_one_audit_entry_and_one_email(fake_payments, django_capture_on_commit_callbacks):
    from django.core import mail

    from core.models import AuditEntry
    from orders.models import Order

    user = make_customer()
    product = make_product()
    make_stock(product, 5)
    with django_capture_on_commit_callbacks(execute=True):
        order = _place(user, [(product, 1)])
    mail.outbox.clear()
    before = AuditEntry.objects.filter(action="order.status_changed").count()
    with django_capture_on_commit_callbacks(execute=True):
        order = Order.objects.get(pk=order.pk)
        order.status = Order.Status.SHIPPED
        order.save()
    assert AuditEntry.objects.filter(action="order.status_changed").count() == before + 1
    assert len(mail.outbox) == 1
    order.save()
    assert AuditEntry.objects.filter(action="order.status_changed").count() == before + 1


def test_status_label_covers_every_stored_status():
    from orders.models import Order

    for value, label in Order.Status.choices:
        assert Order(status=value).status_label == label
    assert {"cancelled", "refunded"} <= {v for v, _ in Order.Status.choices}
