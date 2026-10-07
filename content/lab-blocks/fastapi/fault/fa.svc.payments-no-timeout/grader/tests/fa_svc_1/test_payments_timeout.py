"""Calls to the payments provider must have a bounded timeout, so a slow provider cannot hang the API."""

from app.testing import *  # noqa: F401,F403


def test_payments_client_never_waits_forever_for_the_provider():
    from app.config import Settings
    from app.payments.client import build_http_client

    timeout = build_http_client(Settings()).timeout
    for name in ("connect", "read", "write", "pool"):
        value = getattr(timeout, name)
        assert value is not None, f"the payments client has no {name} timeout"
        assert 0 < value <= 30, f"unreasonable {name} timeout {value!r}"
