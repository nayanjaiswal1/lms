from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def _plan(code="gold"):
    from subscriptions.models import Plan

    return Plan.objects.create(code=code, name=code.title(), monthly_price=9)


def test_subscribe_is_idempotent_for_an_active_plan():
    from subscriptions.models import Subscription

    user, plan = make_customer(), _plan()
    client = authed(user)
    first = client.post("/api/subscriptions/", {"plan": "gold"}, format="json")
    second = client.post("/api/subscriptions/", {"plan": "gold"}, format="json")
    assert (first.status_code, second.status_code) == (201, 200)
    assert first.json()["id"] == second.json()["id"]
    assert Subscription.objects.filter(customer=user, plan=plan).count() == 1


def test_database_rejects_a_second_active_subscription():
    from django.db import IntegrityError, transaction

    from subscriptions.models import Subscription

    user, plan = make_customer(), _plan()
    Subscription.objects.create(customer=user, plan=plan)
    with pytest.raises(IntegrityError), transaction.atomic():
        Subscription.objects.create(customer=user, plan=plan)


def test_resubscribe_after_cancel_is_allowed():
    from subscriptions.models import Subscription

    user, plan = make_customer(), _plan()
    client = authed(user)
    sub = client.post("/api/subscriptions/", {"plan": "gold"}, format="json").json()
    assert client.delete(f"/api/subscriptions/{sub['id']}/").json()["status"] == "canceled"
    again = client.post("/api/subscriptions/", {"plan": "gold"}, format="json")
    assert again.status_code == 201
    assert Subscription.objects.filter(customer=user, plan=plan).count() == 2


def test_cannot_cancel_someone_elses_subscription():
    user, other, _ = make_customer(), make_customer(), _plan()
    sub = authed(user).post("/api/subscriptions/", {"plan": "gold"}, format="json").json()
    assert authed(other).delete(f"/api/subscriptions/{sub['id']}/").status_code == 404


def test_unknown_plan_is_404():
    assert authed(make_customer()).post("/api/subscriptions/", {"plan": "nope"}, format="json").status_code == 404
