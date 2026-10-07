"""Payment failures must reach the client (and monitoring) as error status codes, not as 200 responses."""

import pytest

from app.testing import *  # noqa: F401,F403


@pytest.mark.parametrize(
    ("error_name", "status"),
    [("PaymentDeclined", 402), ("PaymentTimeout", 504), ("PaymentUnavailable", 502)],
)
def test_pay_reports_provider_failures_with_an_error_status(client, db, fake_payments, error_name, status):
    from app.payments import client as payments_client

    customer = make_customer(db)
    order_id = make_order(db, customer, lines=[(make_product(db), 1)])
    fake_payments.error = getattr(payments_client, error_name)("provider failure")
    response = client.post(f"/api/v1/orders/{order_id}/pay", headers=customer.headers)
    assert response.status_code == status
    assert db.one("SELECT status FROM orders WHERE id = %s", order_id) == "pending"
