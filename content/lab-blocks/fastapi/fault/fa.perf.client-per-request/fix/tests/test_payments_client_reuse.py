"""Charges must share one pooled httpx client instead of building a client (and connections) per call."""

import asyncio
from unittest import mock

import httpx

from app.testing import *  # noqa: F401,F403

CHARGES = 5


def test_charges_reuse_one_http_client():
    from app.config import Settings
    from app.payments.client import PaymentsClient

    created = 0
    requests = 0
    original_init = httpx.AsyncClient.__init__

    def counting_init(self, *args, **kwargs):
        nonlocal created
        created += 1
        original_init(self, *args, **kwargs)

    def provider(request: httpx.Request) -> httpx.Response:
        nonlocal requests
        requests += 1
        return httpx.Response(200, json={"id": f"ch_{requests}", "status": "succeeded", "amount_cents": 1500})

    async def scenario() -> None:
        client = PaymentsClient(Settings(), httpx.MockTransport(provider))
        for n in range(CHARGES):
            charge = await client.charge(amount_cents=1500, currency="USD", reference=f"order-{n}", idempotency_key=f"order-{n}")
            assert charge.status == "succeeded"
        await client.aclose()

    with mock.patch.object(httpx.AsyncClient, "__init__", counting_init):
        asyncio.run(scenario())

    assert requests == CHARGES
    assert created == 1, f"{created} httpx clients were built for {CHARGES} charges"
