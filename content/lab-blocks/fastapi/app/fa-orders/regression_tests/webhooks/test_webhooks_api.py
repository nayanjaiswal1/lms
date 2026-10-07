import hashlib
import hmac
import json

from app.testing import *  # noqa: F401,F403


def _post(client, payload, *, secret=None, raw=None):
    body = raw if raw is not None else json.dumps(payload).encode()
    key = (secret or client.app.state.settings.webhook_secret).encode()
    signature = "sha256=" + hmac.new(key, body, hashlib.sha256).hexdigest()
    return client.post("/api/v1/webhooks/payments", content=body, headers={"X-Signature": signature})


def _order(db, status):
    return make_order(db, make_customer(db), lines=[(make_product(db), 1)], status=status)


def test_a_signed_refund_event_refunds_a_paid_order(client, db):
    order_id = _order(db, "paid")
    response = _post(client, {"type": "payment.refunded", "order_id": order_id})
    assert response.status_code == 200
    assert response.json() == {"status": "accepted"}
    assert db.one("SELECT status FROM orders WHERE id = %s", order_id) == "refunded"


def test_refunds_do_not_touch_orders_that_were_never_paid(client, db):
    pending = _order(db, "pending")
    _post(client, {"type": "payment.refunded", "order_id": pending})
    assert db.one("SELECT status FROM orders WHERE id = %s", pending) == "pending"


def test_other_event_types_are_accepted_without_changing_orders(client, db):
    order_id = _order(db, "paid")
    assert _post(client, {"type": "payment.created", "order_id": order_id}).status_code == 200
    assert db.one("SELECT status FROM orders WHERE id = %s", order_id) == "paid"


def test_bad_signatures_are_rejected(client, db):
    order_id = _order(db, "paid")
    wrong = _post(client, {"type": "payment.refunded", "order_id": order_id}, secret="not-the-secret")
    missing = client.post("/api/v1/webhooks/payments", json={"type": "payment.refunded", "order_id": order_id})
    assert wrong.status_code == 401
    assert missing.status_code == 401
    assert db.one("SELECT status FROM orders WHERE id = %s", order_id) == "paid"


def test_malformed_events_are_rejected_after_the_signature_check(client, db):
    assert _post(client, None, raw=b"not json").status_code == 400
    assert _post(client, {"type": "payment.refunded"}).status_code == 400
    assert _post(client, {"type": "payment.refunded", "order_id": "abc"}).status_code == 400
