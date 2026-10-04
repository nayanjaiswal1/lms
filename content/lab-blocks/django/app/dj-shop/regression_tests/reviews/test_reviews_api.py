from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def _review(user, product, rating=5):
    return authed(user).post("/api/reviews/", {"product": product.pk, "rating": rating, "body": "ok"}, format="json")


def test_counters_follow_create_update_delete():
    from catalog.models import Product

    user, product = make_customer(), make_product()
    made = _review(user, product, 4)
    assert made.status_code == 201
    stats = Product.objects.get(pk=product.pk)
    assert (stats.review_count, stats.rating_total) == (1, 4)
    assert authed(user).patch(f"/api/reviews/{made.json()['id']}/", {"rating": 2}, format="json").status_code == 200
    assert Product.objects.get(pk=product.pk).rating_total == 2
    assert authed(user).delete(f"/api/reviews/{made.json()['id']}/").status_code == 204
    stats = Product.objects.get(pk=product.pk)
    assert (stats.review_count, stats.rating_total) == (0, 0)


def test_bulk_purge_keeps_counters_in_sync():
    from catalog.models import Product

    spammer, honest = make_customer(), make_customer()
    products = [make_product() for _ in range(3)]
    for product in products:
        _review(spammer, product, 1)
    _review(honest, products[0], 5)
    resp = authed(make_staff()).delete(f"/api/reviews/purge/?customer={spammer.pk}")
    assert resp.status_code == 200 and resp.json()["deleted"] == 3
    counts = {p.pk: (p.review_count, p.rating_total) for p in Product.objects.filter(pk__in=[p.pk for p in products])}
    assert counts[products[0].pk] == (1, 5)
    assert counts[products[1].pk] == (0, 0) and counts[products[2].pk] == (0, 0)


def test_purge_is_staff_only():
    assert authed(make_customer()).delete("/api/reviews/purge/?customer=1").status_code == 403


def test_only_the_author_can_change_a_review():
    author, intruder = make_customer(), make_customer()
    review = _review(author, make_product()).json()
    url = f"/api/reviews/{review['id']}/"
    assert authed(intruder).patch(url, {"rating": 1}, format="json").status_code == 403
    assert authed(intruder).delete(url).status_code == 403
    assert authed(author).patch(url, {"rating": 3}, format="json").status_code == 200
    assert authed(make_staff()).patch(url, {"rating": 2}, format="json").status_code == 200


def test_anonymous_can_read_but_not_write(api_client):
    product = make_product()
    _review(make_customer(), product)
    assert api_client.get(f"/api/reviews/?product={product.pk}").json()["count"] == 1
    assert api_client.post("/api/reviews/", {"product": product.pk, "rating": 5}, format="json").status_code in (401, 403)


def test_one_review_per_customer_and_product():
    user, product = make_customer(), make_product()
    assert _review(user, product).status_code == 201
    assert _review(user, product).status_code == 400


def test_rating_bounds():
    assert _review(make_customer(), make_product(), 6).status_code == 400
