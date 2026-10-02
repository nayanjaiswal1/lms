"""Settings for the automated test-suite: fast, hermetic, no external services."""

import os

os.environ.setdefault("DJANGO_SECRET_KEY", "test-secret-key")
os.environ.setdefault("DATABASE_URL", "postgresql://labuser@127.0.0.1:5432/app")
os.environ.setdefault("PAYMENTS_BASE_URL", "http://payments.test")
os.environ.setdefault("WEBHOOK_SECRET", "whsec_test")

from .base import *  # noqa: E402,F401,F403

DEBUG = False
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]
CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True
STORAGES = {  # noqa: F405
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}


class _NoMigrations(dict):
    """Build the test database straight from the models (fast, and independent of the migration graph)."""

    def __contains__(self, item):
        return True

    def __getitem__(self, item):
        return None


MIGRATION_MODULES = _NoMigrations()
