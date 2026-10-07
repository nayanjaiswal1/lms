import asyncio

import httpx
import pytest

from app.testing import *  # noqa: F401,F403


def _order(db, customer, status="pending"):
    return make_order(db, customer, lines=[(make_product(db, price_cents=1200), 2)], status=status)


def test_paying_charges_once_and_marks_the_order_paid(client, db, fake_payments):
    customer = make_customer(db)
    order_id = _order(db, customer)
    response = client.post(f"/api/v1/orders/{order_id}/pay", headers=customer.headers)
    assert response.status_code == 200
    assert response.json() == {"order_id": order_id, "status": "succeeded", "charge_id": "ch_0001", "amount_cents": 2400}
    assert fake_payments.charges == [
        {"amount_cents": 2400, "currency": "USD", "reference": f"order-{order_id}", "key": f"order-{order_id}"}
    ]
    assert db.one("SELECT status FROM orders WHERE id = %s", order_id) == "paid"
    assert db.one("SELECT count(*) FROM payments WHERE order_id = %s", order_id) == 1


def test_paying_twice_returns_the_same_payment_without_charging_again(client, db, fake_payments):
    customer = make_customer(db)
    order_id = _order(db, customer)
    first = client.post(f"/api/v1/orders/{order_id}/pay", headers=customer.headers).json()
    second = client.post(f"/api/v1/orders/{order_id}/pay", headers=customer.headers).json()
    assert first == second
    assert len(fake_payments.charges) == 1


def test_only_the_owner_can_pay_and_only_pending_orders_are_payable(client, db, fake_payments):
    customer = make_customer(db)
    stranger = make_customer(db)
    pending = _order(db, customer)
    refunded = _order(db, customer, status="refunded")
    assert client.post(f"/api/v1/orders/{pending}/pay", headers=stranger.headers).status_code == 404
    assert client.post(f"/api/v1/orders/{refunded}/pay", headers=customer.headers).status_code == 409
    assert client.post("/api/v1/orders/999999/pay", headers=customer.headers).status_code == 404
    assert fake_payments.charges == []


def _charge_through(handler, **settings):
    from app.config import Settings
    from app.payments.client import PaymentsClient

    async def run():
        provider = PaymentsClient(
            Settings(payments_base_url="http://provider.test", payments_backoff_seconds=0, **settings),
            transport=httpx.MockTransport(handler),
        )
        try:
            return await provider.charge(amount_cents=500, currency="USD", reference="order-7", idempotency_key="order-7")
        finally:
            await provider.aclose()

    return asyncio.run(run())


def test_charge_sends_an_idempotency_key_and_retries_provider_errors_with_the_same_key():
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request.headers.get("Idempotency-Key"))
        if len(seen) == 1:
            return httpx.Response(503)
        return httpx.Response(200, json={"id": "ch_9", "status": "succeeded", "amount_cents": 500})

    charge = _charge_through(handler)
    assert (charge.id, charge.amount_cents) == ("ch_9", 500)
    assert seen == ["order-7", "order-7"]


def test_charge_does_not_retry_a_decline():
    from app.payments.client import PaymentDeclined

    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(402)

    with pytest.raises(PaymentDeclined):
        _charge_through(handler)
    assert len(calls) == 1


def test_charge_gives_up_after_the_configured_attempts():
    from app.payments.client import PaymentUnavailable

    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(500)

    with pytest.raises(PaymentUnavailable):
        _charge_through(handler, payments_retries=2)
    assert len(calls) == 2

