import hashlib
import hmac
import json

from django.conf import settings

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def _sign(raw):
    return "sha256=" + hmac.new(settings.WEBHOOK_SECRET.encode(), raw, hashlib.sha256).hexdigest()


def _post(client, raw, signature=None):
    return client.post(
        "/webhooks/payments/", data=raw, content_type="application/json",
        HTTP_X_SHOP_SIGNATURE=signature if signature is not None else _sign(raw),
    )  # fmt: skip


def _paid_order(fake_payments):
    from orders import services

    product = make_product()
    make_stock(product, 5)
    return services.place_order(make_customer(), [(product, 1)])


def test_signature_is_computed_over_the_raw_body(client):
    # Whitespace and key order differ from json.dumps output, so re-serialising breaks the HMAC.
    raw = b'{ "type" :  "unknown.event",   "data": {"b": 1,  "a": 2} }'
    assert _post(client, raw).status_code == 200
    assert _post(client, raw, "sha256=" + "0" * 64).status_code == 401
    assert _post(client, raw, "").status_code == 401


def test_tampered_body_is_rejected(client):
    raw = b'{"type": "unknown.event", "data": {}}'
    assert _post(client, raw + b" ", _sign(raw)).status_code == 401


def test_refund_event_marks_order_and_payment_refunded_idempotently(client, fake_payments):
    from orders.models import Order
    from payments.models import Payment

    order = _paid_order(fake_payments)
    raw = json.dumps({"type": "payment.refunded", "data": {"reference": f"order-{order.pk}"}}).encode()
    assert _post(client, raw).json()["handled"] is True
    assert _post(client, raw).json()["handled"] is True
    assert Order.objects.get(pk=order.pk).status == "refunded"
    assert Payment.objects.get(order=order).status == "refunded"


def test_unknown_reference_is_acknowledged_but_not_handled(client):
    raw = json.dumps({"type": "payment.succeeded", "data": {"reference": "order-999999"}}).encode()
    assert _post(client, raw).json()["handled"] is False


def test_malformed_payloads(client):
    assert _post(client, b"not json").status_code == 400
    assert _post(client, b'{"data": {}}').status_code == 400
    assert client.get("/webhooks/payments/").status_code == 405
