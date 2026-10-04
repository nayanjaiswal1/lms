"""HTTP client for the payments provider."""

import logging
from dataclasses import dataclass

import requests
from django.conf import settings
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)


class PaymentError(Exception):
    """Base class for payment failures."""


class PaymentDeclined(PaymentError):
    pass


class TransientPaymentError(PaymentError):
    """Network trouble or a 5xx: safe to retry because charges carry an idempotency key."""


class PaymentContractError(PaymentError):
    """The provider answered with a shape we do not understand."""


@dataclass(frozen=True)
class ChargeResult:
    id: str
    status: str
    amount_cents: int


def parse_charge(data):
    # mf:slot payments.client.parse
    try:
        return ChargeResult(id=data["id"], status=data["status"], amount_cents=data["amount_cents"])
    except (KeyError, TypeError) as exc:
        raise PaymentContractError(f"Unexpected payments response: {exc!r}") from exc
    # mf:endslot


# mf:slot payments.client.retry
_retry = retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=0.2, max=1),
    retry=retry_if_exception_type(TransientPaymentError),
    reraise=True,
)
# mf:endslot


class PaymentsClient:
    def __init__(self, base_url=None):
        self.base_url = (base_url or settings.PAYMENTS_BASE_URL).rstrip("/")
        self.session = requests.Session()

    def _post(self, path, payload, idempotency_key):
        url = f"{self.base_url}{path}"
        try:
            # mf:slot payments.client.request
            response = self.session.post(
                url,
                json=payload,
                headers={"Idempotency-Key": str(idempotency_key)},
                timeout=settings.PAYMENTS_TIMEOUT,
            )
            # mf:endslot
        except (requests.ConnectionError, requests.Timeout) as exc:
            raise TransientPaymentError(str(exc)) from exc
        if response.status_code >= 500:
            raise TransientPaymentError(f"payments returned {response.status_code}")
        if response.status_code == 402:
            raise PaymentDeclined(response.text[:200])
        response.raise_for_status()
        return response.json()

    @_retry
    def charge(self, *, amount_cents, currency, reference, idempotency_key):
        data = self._post(
            "/v1/charges",
            {"amount_cents": amount_cents, "currency": currency, "reference": reference},
            idempotency_key,
        )
        return parse_charge(data)
