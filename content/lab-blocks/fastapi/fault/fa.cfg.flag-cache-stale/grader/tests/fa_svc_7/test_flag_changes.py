"""A flag that staff change must change the application's behavior on the next request."""

from app.testing import *  # noqa: F401,F403


def _pay_new_order(client, db, customer):
    order_id = make_order(db, customer, lines=[(make_product(db), 1)])
    return client.post(f"/api/v1/orders/{order_id}/pay", headers=customer.headers)


def test_payments_are_on_while_the_kill_switch_flag_does_not_exist(client, db, fake_payments):
    customer = make_customer(db)
    assert _pay_new_order(client, db, customer).status_code == 200


def test_switching_payments_off_and_on_takes_effect_on_the_next_payment(client, db, fake_payments):
    staff = make_staff(db)
    customer = make_customer(db)

    def switch(enabled):
        response = client.put("/api/v1/staff/flags/payments_enabled", json={"enabled": enabled}, headers=staff.headers)
        assert response.status_code == 200

    switch(True)
    assert _pay_new_order(client, db, customer).status_code == 200
    switch(False)
    assert _pay_new_order(client, db, customer).status_code == 503
    assert len(fake_payments.charges) == 1, "a payment went through while the kill switch was off"
    switch(True)
    assert _pay_new_order(client, db, customer).status_code == 200
    assert len(fake_payments.charges) == 2
