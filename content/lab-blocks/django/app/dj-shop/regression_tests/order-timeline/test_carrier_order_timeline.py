from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_timeline_has_events_and_is_owner_only(fake_payments):
    from orders import services

    owner, intruder = make_customer(), make_customer()
    product = make_product()
    make_stock(product, 5)
    order = services.place_order(owner, [(product, 1)])
    body = authed(owner).get(f"/api/orders/{order.pk}/timeline/").json()
    names = [e["event"] for e in body["events"]]
    assert "order.created" in names and "payment.succeeded" in names
    assert authed(intruder).get(f"/api/orders/{order.pk}/timeline/").status_code == 404
