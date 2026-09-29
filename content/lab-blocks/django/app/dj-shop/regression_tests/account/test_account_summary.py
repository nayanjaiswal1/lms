from django.core.cache import cache

from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def setup_function():
    cache.clear()


def test_summary_is_per_user_not_shared():
    alice, bob = make_customer(full_name="Alice"), make_customer(full_name="Bob")
    a = authed(alice).get("/api/me/summary/").json()
    b = authed(bob).get("/api/me/summary/").json()
    assert (a["name"], b["name"]) == ("Alice", "Bob")
    assert a["email"] != b["email"]


def test_profile_edit_shows_up_immediately():
    user = make_customer(full_name="Before")
    client = authed(user)
    assert client.get("/api/me/summary/").json()["name"] == "Before"
    client.patch("/api/me/", {"full_name": "After"}, format="json")
    assert client.get("/api/me/summary/").json()["name"] == "After"


def test_summary_is_cached_between_requests(django_assert_num_queries):
    user = make_customer()
    client = authed(user)
    client.get("/api/me/summary/")
    with django_assert_num_queries(0):
        client.get("/api/me/summary/")


def test_summary_requires_login(api_client):
    assert api_client.get("/api/me/summary/").status_code in (401, 403)
