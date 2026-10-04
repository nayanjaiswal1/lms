"""The production settings must serve the collected static files without DEBUG."""

from core.testing import *  # noqa: F401,F403


def test_production_settings_serve_static_files_and_keep_debug_off():
    import importlib

    prod = importlib.import_module("config.settings.prod")
    middleware = prod.MIDDLEWARE
    assert prod.DEBUG is False
    assert prod.STATIC_ROOT
    static = "whitenoise.middleware.WhiteNoiseMiddleware"
    assert static in middleware, "nothing serves the collected static files in production"
    assert middleware.index("django.middleware.security.SecurityMiddleware") < middleware.index(static)
    assert middleware.index(static) < middleware.index("django.contrib.sessions.middleware.SessionMiddleware")
