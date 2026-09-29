"""Small helpers for reading configuration from the environment."""

import os
from urllib.parse import unquote, urlsplit

from django.core.exceptions import ImproperlyConfigured

_TRUE = {"1", "true", "yes", "on"}


def require_env(name):
    """Return a required variable; a missing one is a deployment error."""
    value = os.environ.get(name)
    if not value:
        raise ImproperlyConfigured(f"Environment variable {name} is required")
    return value


def env_str(name, default=""):
    return os.environ.get(name, default)


def env_bool(name, default=False):
    raw = os.environ.get(name)
    return default if raw is None else raw.strip().lower() in _TRUE


def env_int(name, default):
    raw = os.environ.get(name)
    return default if raw is None or raw == "" else int(raw)


def env_list(name, default=()):
    raw = os.environ.get(name)
    if raw is None:
        return list(default)
    return [part.strip() for part in raw.split(",") if part.strip()]


def database_from_url(url):
    """Translate a ``postgresql://`` or ``sqlite:///`` URL into a DATABASES entry."""
    parts = urlsplit(url)
    if parts.scheme in ("postgres", "postgresql"):
        return {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": parts.path.lstrip("/"),
            "USER": unquote(parts.username or ""),
            "PASSWORD": unquote(parts.password or ""),
            "HOST": parts.hostname or "",
            "PORT": str(parts.port or ""),
        }
    if parts.scheme == "sqlite":
        return {"ENGINE": "django.db.backends.sqlite3", "NAME": unquote(parts.path[1:]) or ":memory:"}
    raise ImproperlyConfigured(f"Unsupported DATABASE_URL scheme: {parts.scheme!r}")
