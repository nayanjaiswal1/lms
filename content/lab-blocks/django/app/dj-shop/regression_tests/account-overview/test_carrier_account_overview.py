from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_overview_counts_my_activity():
    from reviews.models import Review
    from subscriptions.models import Plan, Subscription

    user = make_customer()
    product = make_product()
    Review.objects.create(product=product, customer=user, rating=5)
    Subscription.objects.create(customer=user, plan=Plan.objects.create(code="gold", name="Gold", monthly_price=9))
    body = authed(user).get("/api/me/overview/").json()
    assert body == {"orders": 0, "reviews": 1, "active_subscriptions": 1}
    assert authed(make_customer()).get("/api/me/overview/").json()["reviews"] == 0
