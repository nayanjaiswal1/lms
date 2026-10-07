"""Every retry of one charge must carry the same idempotency key, so the provider can recognise the duplicate."""

import asyncio

import httpx

from app.testing import *  # noqa: F401,F403


def _charge_through(handler):
    from app.config import Settings
    from app.payments.client import PaymentsClient

    async def run():
        provider = PaymentsClient(
            Settings(payments_base_url="http://provider.test", payments_backoff_seconds=0, payments_retries=3),
            transport=httpx.MockTransport(handler),
        )
        try:
            return await provider.charge(amount_cents=500, currency="USD", reference="order-7", idempotency_key="order-7")
        finally:
            await provider.aclose()

    return asyncio.run(run())


def test_retries_reuse_the_idempotency_key():
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request.headers.get("Idempotency-Key"))
        if len(seen) < 3:
            return httpx.Response(500)
        return httpx.Response(200, json={"id": "ch_1", "status": "succeeded", "amount_cents": 500})

    _charge_through(handler)
    assert seen == ["order-7"] * 3


def test_a_lost_response_does_not_charge_the_customer_twice():
    """A provider that records the charge and then fails (a lost response) must see one charge per idempotency key."""
    recorded = {}
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        key = request.headers["Idempotency-Key"]
        calls.append(key)
        recorded.setdefault(key, {"id": f"ch_{len(recorded) + 1}", "status": "succeeded", "amount_cents": 500})
        if len(calls) == 1:
            return httpx.Response(500)
        return httpx.Response(200, json=recorded[key])

    charge = _charge_through(handler)
    assert charge.amount_cents == 500
    assert len(recorded) == 1
