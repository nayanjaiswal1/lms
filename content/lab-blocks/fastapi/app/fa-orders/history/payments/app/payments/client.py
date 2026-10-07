"""Client for the external card payments provider."""

from dataclasses import dataclass

import httpx
from tenacity import AsyncRetrying, retry_if_exception_type, stop_after_attempt, wait_fixed

from app.config import Settings


class PaymentError(Exception):
    pass


class PaymentDeclined(PaymentError):
    pass


class PaymentUnavailable(PaymentError):
    """The provider could not be reached or kept failing."""


class PaymentTimeout(PaymentUnavailable):
    pass


class ProviderServerError(Exception):
    """The provider answered 5xx. Transient: charging again with the same idempotency key is safe."""


@dataclass(frozen=True)
class Charge:
    id: str
    status: str
    amount_cents: int


def build_http_client(settings: Settings, transport: httpx.AsyncBaseTransport | None = None) -> httpx.AsyncClient:
    # mf:slot payments.client.http_client
    return httpx.AsyncClient(
        base_url=settings.payments_base_url,
        timeout=settings.payments_timeout_seconds,
        transport=transport,
    )
    # mf:endslot


class PaymentsClient:
    def __init__(self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None):
        self._settings = settings
        self._transport = transport
        self._http = build_http_client(settings, transport)
        self._attempts = settings.payments_retries
        self._backoff = settings.payments_backoff_seconds

    async def aclose(self) -> None:
        await self._http.aclose()

    async def charge(self, *, amount_cents: int, currency: str, reference: str, idempotency_key: str) -> Charge:
        # mf:slot payments.client.headers
        headers = {"Idempotency-Key": idempotency_key}
        # mf:endslot
        payload = {"amount_cents": amount_cents, "currency": currency, "reference": reference}
        retrying = AsyncRetrying(
            stop=stop_after_attempt(self._attempts),
            wait=wait_fixed(self._backoff),
            retry=retry_if_exception_type((ProviderServerError, httpx.ConnectError)),
            reraise=True,
        )
        try:
            async for attempt in retrying:
                with attempt:
                    # mf:slot payments.client.send
                    response = await self._http.post("/v1/charges", json=payload, headers=headers)
                    # mf:endslot
                    if response.status_code == 402:
                        raise PaymentDeclined("card declined")
                    if response.status_code >= 500:
                        raise ProviderServerError(f"provider answered {response.status_code}")
                    if response.status_code != 200:
                        raise PaymentError(f"unexpected provider status {response.status_code}")
        except httpx.TimeoutException as exc:
            raise PaymentTimeout("payments provider timed out") from exc
        except (ProviderServerError, httpx.TransportError) as exc:
            raise PaymentUnavailable("payments provider unavailable") from exc
        body = response.json()
        return Charge(id=body["id"], status=body["status"], amount_cents=body["amount_cents"])
