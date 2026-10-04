import pytest
from django.core.exceptions import ImproperlyConfigured

from core.testing import *  # noqa: F401,F403


def test_database_url_postgres():
    from config.settings.env import database_from_url

    cfg = database_from_url("postgresql://shop:s%40cret@db.internal:6543/shopdb")
    assert cfg["ENGINE"] == "django.db.backends.postgresql"
    assert (cfg["NAME"], cfg["USER"], cfg["PASSWORD"], cfg["HOST"], cfg["PORT"]) == (
        "shopdb", "shop", "s@cret", "db.internal", "6543",
    )  # fmt: skip


def test_database_url_rejects_unknown_scheme():
    from config.settings.env import database_from_url

    with pytest.raises(ImproperlyConfigured):
        database_from_url("mysql://x/y")


def test_missing_required_env_fails_fast(monkeypatch):
    from config.settings.env import require_env

    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(ImproperlyConfigured):
        require_env("DATABASE_URL")


def test_env_helpers(monkeypatch):
    from config.settings.env import env_bool, env_int, env_list

    monkeypatch.setenv("A_FLAG", "Yes")
    monkeypatch.setenv("A_NUM", "7")
    monkeypatch.setenv("A_LIST", "a, b ,,c")
    assert env_bool("A_FLAG") is True
    assert env_int("A_NUM", 1) == 7
    assert env_list("A_LIST") == ["a", "b", "c"]


def test_time_settings(settings):
    assert settings.USE_TZ is True
    assert settings.TIME_ZONE == "America/New_York"


def test_middleware_order(settings):
    mw = settings.MIDDLEWARE
    assert mw.index("django.contrib.sessions.middleware.SessionMiddleware") < mw.index(
        "django.contrib.auth.middleware.AuthenticationMiddleware"
    )
    assert mw.index("django.contrib.auth.middleware.AuthenticationMiddleware") < mw.index(
        "core.middleware.RequestContextMiddleware"
    )
