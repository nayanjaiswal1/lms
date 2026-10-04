"""Local development settings."""

from .base import *  # noqa: F401,F403
from .env import env_bool

DEBUG = env_bool("DJANGO_DEBUG", True)
STORAGES = {  # noqa: F405
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}
