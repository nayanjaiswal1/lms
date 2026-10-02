"""The slug backfill must give every existing review a distinct, non-empty slug, even without titles."""

import importlib

from core.testing import *  # noqa: F401,F403


def test_backfilled_slugs_are_unique_and_never_the_string_none():
    migration = importlib.import_module("reviews.migrations.0002_review_slug")
    titles = [None, None, "", "Great", "Great", "Great value!"]
    slugs = [migration.build_slug(title, pk) for pk, title in enumerate(titles, start=1)]
    assert len(set(slugs)) == len(titles)
    assert all(slug and slug != "none" and not slug.startswith("none-") for slug in slugs)
    assert migration.build_slug("Great value!", 6).startswith("great-value-")
