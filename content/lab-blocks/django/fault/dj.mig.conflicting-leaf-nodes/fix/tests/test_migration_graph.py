"""Every app has exactly one migration leaf, so `migrate` has a single, unambiguous target."""

from django.db.migrations.loader import MigrationLoader

from core.testing import *  # noqa: F401,F403


def test_migration_graph_has_no_conflicting_leaf_nodes(settings):
    settings.MIGRATION_MODULES = {}  # the test settings skip migrations; load the real ones for this check
    conflicts = MigrationLoader(None, ignore_no_migrations=True).detect_conflicts()
    assert conflicts == {}, f"conflicting leaf nodes: {conflicts}"
