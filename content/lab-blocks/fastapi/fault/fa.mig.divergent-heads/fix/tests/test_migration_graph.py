"""The Alembic revision graph must have exactly one head, and the migrations must apply on an empty database."""

from alembic.config import Config
from alembic.script import ScriptDirectory

from app.testing import *  # noqa: F401,F403


def _script_directory() -> ScriptDirectory:
    config = Config(str(PROJECT_ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(PROJECT_ROOT / "alembic"))
    return ScriptDirectory.from_config(config)


def test_revision_graph_has_a_single_head():
    assert len(_script_directory().get_heads()) == 1


def test_upgrade_head_applies_on_an_empty_database(scratch_database_url):
    result = alembic_cli(scratch_database_url, "upgrade", "head")
    assert result.returncode == 0, result.stderr
