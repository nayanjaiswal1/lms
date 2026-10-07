"""A request that ends in a server error must give its database connection back."""

from app.testing import *  # noqa: F401,F403


def test_failed_payments_give_their_connection_back(client, db, fake_payments):
    from app.payments.client import PaymentTimeout, PaymentUnavailable

    customer = make_customer(db)
    product = make_product(db)
    pool = client.app.state.engine.pool
    for error, status in ((PaymentUnavailable("provider down"), 502), (PaymentTimeout("provider slow"), 504)):
        fake_payments.error = error
        for _ in range(3):
            order_id = make_order(db, customer, lines=[(product, 1)])
            assert client.post(f"/api/v1/orders/{order_id}/pay", headers=customer.headers).status_code == status
            assert pool.checkedout() == 0, "a failed request is still holding a database connection"
    assert db.one("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND state = 'idle in transaction'") == 0

    fake_payments.error = None
    assert client.post(f"/api/v1/orders/{order_id}/pay", headers=customer.headers).status_code == 200
