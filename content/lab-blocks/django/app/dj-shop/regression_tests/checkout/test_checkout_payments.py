import pytest
import requests

from core.testing import *  # noqa: F401,F403

KEY = "11111111-1111-1111-1111-111111111111"
GOOD = {"id": "ch_1", "status": "succeeded", "amount_cents": 500, "currency": "USD"}


class _Resp:
    def __init__(self, status=200, data=None):
        self.status_code = status
        self._data = data or {}
        self.text = str(self._data)

    def json(self):
        return self._data

    def raise_for_status(self):
        if self.status_code >= 400:
            raise requests.HTTPError(str(self.status_code))


def _client(monkeypatch, replies):
    from payments.client import PaymentsClient

    client = PaymentsClient("http://payments.test")
    calls = []

    def fake_post(url, json=None, headers=None, timeout=None):
        calls.append({"url": url, "json": json, "headers": headers or {}, "timeout": timeout})
        reply = replies.pop(0)
        if isinstance(reply, Exception):
            raise reply
        return reply

    monkeypatch.setattr(client.session, "post", fake_post)
    return client, calls


def _charge(client):
    return client.charge(amount_cents=500, currency="USD", reference="order-1", idempotency_key=KEY)


def test_charge_sends_idempotency_key_and_timeout(monkeypatch):
    client, calls = _client(monkeypatch, [_Resp(200, GOOD)])
    assert _charge(client).status == "succeeded"
    assert calls[0]["headers"]["Idempotency-Key"] == KEY
    assert calls[0]["timeout"] is not None


def test_retry_reuses_the_same_idempotency_key(monkeypatch):
    client, calls = _client(monkeypatch, [_Resp(503), requests.Timeout("slow"), _Resp(200, GOOD)])
    assert _charge(client).id == "ch_1"
    assert len(calls) == 3
    assert {c["headers"]["Idempotency-Key"] for c in calls} == {KEY}


def test_gives_up_after_three_attempts(monkeypatch):
    from payments.client import TransientPaymentError

    client, calls = _client(monkeypatch, [_Resp(500)] * 3)
    with pytest.raises(TransientPaymentError):
        _charge(client)
    assert len(calls) == 3


def test_decline_is_not_retried(monkeypatch):
    from payments.client import PaymentDeclined

    client, calls = _client(monkeypatch, [_Resp(402, {"error": "card_declined"})])
    with pytest.raises(PaymentDeclined):
        _charge(client)
    assert len(calls) == 1


def test_unexpected_response_shape_fails_loudly(monkeypatch):
    from payments.client import PaymentContractError

    client, _ = _client(monkeypatch, [_Resp(200, {"charge": "ch_9", "state": "succeeded"})])
    with pytest.raises(PaymentContractError):
        _charge(client)
