"""Calls to the payments provider always carry a sensible timeout."""

from core.testing import *  # noqa: F401,F403


class _Ok:
    status_code = 200
    text = ""

    def json(self):
        return {"id": "ch_1", "status": "succeeded", "amount_cents": 100}

    def raise_for_status(self):
        return None


def test_charge_never_waits_forever_for_the_provider(monkeypatch):
    from payments.client import PaymentsClient

    client = PaymentsClient("http://payments.test")
    calls = []
    monkeypatch.setattr(client.session, "post", lambda url, **kwargs: calls.append(kwargs) or _Ok())
    client.charge(amount_cents=100, currency="USD", reference="order-1", idempotency_key="k-1")
    timeout = calls[0].get("timeout")
    assert timeout is not None, "the request has no timeout"
    connect, read = timeout if isinstance(timeout, tuple) else (timeout, timeout)
    assert 0 < connect <= 10 and 0 < read <= 30, f"unreasonable timeout {timeout!r}"
